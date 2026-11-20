import argparse
import csv
import json
import os
import platform
import re
import subprocess
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread

from api_demo import crear_servidor


def comprobar(condicion, razon):
    if not condicion:
        raise RuntimeError(razon)


class ApiConFallos(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/invalido":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'[{"IdComment":"DEMO","Comentario":"DATO_PRIVADO_DE_PRUEBA"},')
        else:
            self.send_error(503)

    def log_message(self, formato, *argumentos):
        return


@contextmanager
def servir(servidor):
    with servidor:
        hilo = Thread(target=servidor.serve_forever, daemon=True)
        hilo.start()
        try:
            yield f"http://127.0.0.1:{servidor.server_port}"
        finally:
            servidor.shutdown()
            hilo.join()


def leer_csv(ruta):
    with ruta.open(encoding="utf-8-sig", newline="") as archivo:
        return list(csv.DictReader(archivo, strict=True))


def preparar_volumen(encuestas, ruta, total):
    comprobar(total >= len(encuestas) > 0, "Cantidad de encuestas incompatible con la prueba.")
    with ruta.open("w", encoding="utf-8", newline="") as archivo:
        escritor = csv.DictWriter(archivo, fieldnames=list(encuestas[0]))
        escritor.writeheader()
        escritor.writerows(encuestas)
        for indice in range(len(encuestas), total):
            escritor.writerow({
                "IdOpinion": f"SINT-{indice + 1:05d}", "IdCliente": "C001", "IdProducto": "P001",
                "Fecha": "2026-01-01", "Comentario": "Encuesta sintética para medir la extracción.",
                "Clasificación": "Neutra", "PuntajeSatisfacción": "3", "Fuente": "PruebaSintetica"
            })


def ejecutar(args, caso, archivo, url, conexion, exito, marcador=None):
    staging = args.evidencia / caso
    entorno = {
        clave: valor for clave, valor in os.environ.items()
        if not clave.casefold().startswith(("extraccion__", "connectionstrings__", "dotnet_environment"))
    }
    entorno.update({
        "Extraccion__EncuestasCsv": str(archivo),
        "Extraccion__DirectorioTemporal": str(staging),
        "Extraccion__Api__Url": url,
        "Extraccion__Api__PermitirHttpLocal": "true",
        "ConnectionStrings__Resenas": conexion
    })

    inicio = time.perf_counter()
    resultado = subprocess.run(["dotnet", str(args.worker)], env=entorno, capture_output=True,
                               encoding="utf-8", errors="replace", timeout=330)
    segundos = round(time.perf_counter() - inicio, 3)
    registro = resultado.stdout + resultado.stderr
    comprobar(conexion not in registro and "DATO_PRIVADO_DE_PRUEBA" not in registro,
              f"{caso} registró datos privados.")
    (args.evidencia / f"{caso}.log").write_text(registro, encoding="utf-8")
    comprobar(resultado.returncode == (0 if exito else 1),
              f"{caso} devolvió código {resultado.returncode}. Revisa su log local.")
    comprobar(marcador is None or marcador in registro, f"{caso} carece del diagnóstico esperado.")
    comprobar(".NET 8." in registro, f"{caso} se ejecutó en otro runtime.")
    carpetas = list(staging.iterdir()) if staging.is_dir() else []
    if not exito:
        comprobar(not carpetas, f"{caso} dejó staging publicado o parcial.")
        return None

    comprobar(len(carpetas) == 1 and not carpetas[0].name.endswith(".partial"),
              f"{caso} tiene staging inesperado.")
    filas_por_fuente = {}
    for fuente in ("encuestas-csv", "resenas-sql", "comentarios-api"):
        with (carpetas[0] / f"{fuente}.ndjson").open(encoding="utf-8") as flujo:
            filas_por_fuente[fuente] = [json.loads(linea) for linea in flujo]
        comprobar(any(len(fila.get("Comentario") or "") >= 15 for fila in filas_por_fuente[fuente]),
                  f"{caso} carece de comentarios para verificar el log.")
        for fila in filas_por_fuente[fuente]:
            comentario = fila.get("Comentario") or ""
            if len(comentario) >= 15:
                comprobar(comentario not in registro, f"{caso} volcó un comentario al log.")

    metricas = {
        fuente: {"filas": int(filas), "ms": int(ms)}
        for fuente, filas, ms in re.findall(r"Fuente (\S+) completa\. Filas=(\d+) Duraci.nMs=(\d+)", registro)
    }
    total = re.search(r"Total=(\d+) Duraci.nMs=(\d+)", registro)
    comprobar(total is not None and all(
        metricas.get(fuente, {}).get("filas") == len(filas)
        for fuente, filas in filas_por_fuente.items()), f"{caso} tiene métricas inconsistentes.")
    comprobar(int(total[1]) == sum(map(len, filas_por_fuente.values())), f"{caso} tiene un total inconsistente.")
    return filas_por_fuente, {
        "fuentes": metricas, "total": int(total[1]), "ms": int(total[2]), "segundos_proceso": segundos,
        "runtime": re.search(r"Worker de extracción iniciado sobre (.+)\.", registro)[1]
    }


def main():
    parser = argparse.ArgumentParser(description="Verifica CSV, SQL Server y HTTP del Worker en .NET 8.")
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--evidencia", type=Path, required=True)
    parser.add_argument("--worker", type=Path, default=Path("src/ETL.Worker/bin/Release/net8.0/ETL.Worker.dll"))
    parser.add_argument("--resenas", type=int, default=200)
    args = parser.parse_args()

    conexion = os.environ.get("ConnectionStrings__Resenas")
    comprobar(conexion, "Configura ConnectionStrings__Resenas antes de verificar.")
    comprobar(args.worker.is_file(), "Compila ETL.Worker en Release antes de verificar.")
    encuestas_csv = args.csv / "surveys_part1.csv"
    comentarios_csv = args.csv / "social_comments.csv"
    encuestas = leer_csv(encuestas_csv)
    comentarios = leer_csv(comentarios_csv)

    args.evidencia.mkdir(parents=True, exist_ok=False)
    volumen = args.evidencia / "encuestas-rendimiento.csv"
    preparar_volumen(encuestas, volumen, 50000 - args.resenas - len(comentarios))
    invalido = args.evidencia / "encabezado-invalido.csv"
    invalido.write_text("IdOpinion,Comentario\nUN01,DATO_PRIVADO_DE_PRUEBA\n", encoding="utf-8")

    with servir(crear_servidor(comentarios_csv, 0)) as base:
        url = f"{base}/comentarios"
        filas, normal = ejecutar(args, "academica", encuestas_csv, url, conexion, exito=True)
        comprobar(filas["encuestas-csv"] == encuestas and filas["comentarios-api"] == comentarios,
                  "Los archivos de staging difieren de sus orígenes.")
        resenas = filas["resenas-sql"]
        comprobar(len(resenas) == args.resenas and len({fila["IdReview"] for fila in resenas}) == args.resenas
                  and all(isinstance(fila["IdReview"], str) for fila in resenas),
                  "Conteo o identificadores SQL inesperados.")
        _, rendimiento = ejecutar(args, "rendimiento", volumen, url, conexion, exito=True)
        comprobar(rendimiento["total"] == 50000 and rendimiento["segundos_proceso"] < 300,
                  "La corrida de volumen no cumplió 50000 registros en menos de 300 segundos.")

        ejecutar(args, "csv-invalido", invalido, url, conexion, exito=False,
                 marcador="Fuente encuestas-csv fallida")
        conexion_invalida = ("Server=tcp:127.0.0.1,1;Database=master;Integrated Security=True;"
                             "Encrypt=True;Connect Timeout=1;ConnectRetryCount=0")
        ejecutar(args, "sql-no-disponible", encuestas_csv, url, conexion_invalida, exito=False,
                 marcador="Fuente resenas-sql fallida")

    with servir(ThreadingHTTPServer(("127.0.0.1", 0), ApiConFallos)) as base:
        ejecutar(args, "http-no-disponible", encuestas_csv, f"{base}/error", conexion, exito=False,
                 marcador="Http=503")
        ejecutar(args, "json-invalido", encuestas_csv, f"{base}/invalido", conexion, exito=False,
                 marcador="Fuente comentarios-api fallida")

    metricas = {
        "entorno": {"sistema": platform.system(), "arquitectura": platform.machine()},
        "academica": normal, "rendimiento": rendimiento,
        "encuestas_sinteticas": rendimiento["fuentes"]["encuestas-csv"]["filas"] - len(encuestas),
        "fallos_verificados": ["csv-invalido", "sql-no-disponible", "http-no-disponible", "json-invalido"]
    }
    salida = json.dumps(metricas, ensure_ascii=True, indent=2)
    (args.evidencia / "resumen.json").write_text(salida + "\n", encoding="utf-8")
    print(salida)


if __name__ == "__main__":
    main()
