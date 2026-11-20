import argparse
import csv
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


COLUMNAS = {"IdComment", "IdCliente", "IdProducto", "Fuente", "Fecha", "Comentario"}


def crear_servidor(archivo: Path, puerto: int) -> ThreadingHTTPServer:
    if not archivo.is_file():
        raise FileNotFoundError("Indica un archivo social_comments.csv existente.")

    class ApiDemostracion(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/comentarios":
                self.send_error(404)
                return

            with archivo.open(encoding="utf-8-sig", newline="") as entrada:
                lector = csv.DictReader(entrada, strict=True)
                columnas = lector.fieldnames or []
                if len(columnas) != len(COLUMNAS) or set(columnas) != COLUMNAS:
                    self.send_error(500, "Encabezado CSV invalido")
                    return

                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                try:
                    self.wfile.write(b"[")
                    separador = b""
                    for fila in lector:
                        if None in fila or None in fila.values():
                            self.close_connection = True
                            return
                        self.wfile.write(separador + json.dumps(fila, ensure_ascii=False).encode("utf-8"))
                        separador = b","
                    self.wfile.write(b"]")
                except (csv.Error, UnicodeError, OSError):
                    self.close_connection = True

        def log_message(self, formato, *argumentos):
            return

    return ThreadingHTTPServer(("127.0.0.1", puerto), ApiDemostracion)


def main():
    parser = argparse.ArgumentParser(description="API REST de demostración en loopback.")
    parser.add_argument("csv", type=Path)
    parser.add_argument("--puerto", type=int, default=8765)
    argumentos = parser.parse_args()

    with crear_servidor(argumentos.csv, argumentos.puerto) as servidor:
        print(f"API demo en http://127.0.0.1:{servidor.server_port}/comentarios", flush=True)
        try:
            servidor.serve_forever()
        except KeyboardInterrupt:
            return


if __name__ == "__main__":
    main()
