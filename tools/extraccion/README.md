# Actividad 1 · Worker de extracción

El Worker ejecuta una corrida, consulta en paralelo las tres fuentes y publica una carpeta privada con un archivo NDJSON por fuente. La consola de validación y carga transaccional también está disponible.

## Requisitos

- SDK .NET 10 para compilar la solución y runtime ASP.NET Core 8 para ejecutar el Worker `net8.0`.
- SQL Server con `AnalisisOpinionesClientes` y la vista `dbo.vw_OpinionesDetalle`. Para preparar una instancia académica nueva, aplica los [scripts de base de datos](../../database/README.md) y usa [la carga anterior](../../README.md#ejecutar-la-carga-sql) con los seis CSV originales. El código 2 indica carga confirmada con rechazos.
- `surveys_part1.csv` y, para la demo, `social_comments.csv`. El material académico se obtiene aparte.
- Python 3 para la API local y el verificador. El Worker puede consumir una API compatible sin Python.

## Ejecutar con la API local

En una terminal, desde la raíz:

```powershell
python tools/extraccion/api_demo.py "C:\datos\social_comments.csv"
```

En otra terminal, desde la raíz:

```powershell
$env:Extraccion__EncuestasCsv = 'C:\datos\surveys_part1.csv'
$env:Extraccion__DirectorioTemporal = Join-Path $env:LOCALAPPDATA 'SistemaAnalisisOpiniones\staging'
$env:Extraccion__Api__Url = 'http://127.0.0.1:8765/comentarios'
$env:Extraccion__Api__PermitirHttpLocal = 'true'
$env:ConnectionStrings__Resenas = 'Server=SERVIDOR;Database=AnalisisOpinionesClientes;Integrated Security=True;Encrypt=True;'
dotnet run --project src/ETL.Worker/ETL.Worker.csproj -c Release
```

Ajusta la conexión al servidor y su certificado. Para el despliegue, usa una identidad SQL restringida con `SELECT` sobre `dbo.vw_OpinionesDetalle` y permisos de escritura en el directorio privado de staging. El Worker solo lee de SQL. El DBA puede conceder el permiso a un usuario de base existente con `GRANT SELECT ON OBJECT::dbo.vw_OpinionesDetalle TO [UsuarioEtlExtraccion]`.

Para una API remota, configura una URL HTTPS y deja `Extraccion__Api__PermitirHttpLocal` en `false`. Si el endpoint usa autenticación Bearer, inyecta `Extraccion__Api__Token` desde el entorno del proceso o un gestor de secretos. Valida los certificados del servicio SQL y de HTTPS. Mantén contraseñas y tokens fuera del JSON versionado, Git y argumentos de terminal.

El contrato HTTP es un arreglo JSON de objetos con `IdComment` y `Comentario` de tipo texto. Se conservan los campos adicionales. La demo lee el archivo académico y lo expone por HTTP solo al equipo local. Un proveedor paginado o con otro esquema requiere un adaptador.

## Revisar los resultados

| Archivo | Contenido |
| --- | --- |
| `encuestas-csv.ndjson` | Campos de las encuestas, incluidos códigos y puntajes como texto. |
| `resenas-sql.ndjson` | Reseñas Web con identificadores de origen, fecha, comentario y rating. |
| `comentarios-api.ndjson` | Objetos obtenidos mediante HTTP. |

Cada línea es un objeto JSON. La extracción valida la estructura y conserva los datos de origen para la transformación posterior. Los logs contienen conteos, duración, estado y tipos de error. El código 0 indica que se cerraron y publicaron los tres archivos. El código 1 indica fallo de configuración o extracción. Una cancelación solicitada devuelve 130.

Las corridas parciales usan el sufijo `.partial` y se descartan al manejar una cancelación o un fallo. Una terminación forzada puede dejar un parcial huérfano. El consumidor debe aceptar únicamente carpetas finales. Cada reejecución usa un directorio distinto.

## Reproducir las pruebas y la medición

Desde la raíz, con la cadena SQL de arriba configurada y una ruta de evidencias que aún no exista:

```powershell
dotnet build SistemaAnalisisOpiniones.sln -c Release
dotnet test --solution SistemaAnalisisOpiniones.sln --configuration Release
python tools/extraccion/verificar.py --csv "C:\datos" --evidencia "reportes-locales\extraccion-prueba"
```

El verificador inicia su propia API en loopback. Contrasta CSV y API con sus originales, valida los conteos de SQL y comprueba cuatro fallos sin staging publicado. La opción `--resenas` ajusta el conteo SQL esperado. El ensayo completa 50 000 registros con encuestas sintéticas y mide extracción más escritura temporal. La transformación y la carga analítica se medirán en sus etapas. La carpeta de evidencias contiene datos extraídos y debe mantenerse privada.
