# Base de datos de la carga transaccional

Base: `AnalisisOpinionesClientes`, SQL Server. Esta carpeta contiene esquema, procedimientos, vistas y verificaciones; los scripts no cargan los CSV. La aplicación .NET en src/ ejecuta la validación y la carga mediante --validar y --cargar.

## Archivos y ejecución

Ejecutar desde la raíz del proyecto, en este orden, con una instancia y una cuenta autorizadas. En el equipo de desarrollo se comprobó la instancia local mediante `lpc:.` y autenticación integrada; el servidor debe ajustarse al reproducirlo en otro entorno.

```powershell
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/01_crear_base_datos.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/02_procedimientos.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/03_vistas.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/04_consultas_validacion.sql
```

- `01_crear_base_datos.sql`: crea la base y las cuatro tablas si faltan, o amplía el modelo anterior cuando no hay filas sin correspondencia externa. Usa transacción para los cambios de tablas, conserva las PK internas y no borra registros. Si una tabla contiene filas y necesita columnas de origen, detiene la adaptación para exigir una migración revisada.
- `02_procedimientos.sql`: crea o actualiza cinco procedimientos. Puede repetirse sin borrar datos.
- `03_vistas.sql`: crea o actualiza las tres vistas de detalle, clasificación pendiente y calidad referencial.
- `04_consultas_validacion.sql`: nueve comprobaciones de conteos, relaciones, duplicados, clasificación pendiente, detalle, canal/fuente y estado de las FK. Los resultados vacíos de huérfanos y duplicados son esperados; una base vacía no demuestra una carga CSV exitosa.
- `05_pruebas_base_datos.sql`: comprueba comportamiento con datos temporales identificados como pruebas y transacciones que se revierten. No es la carga real ni su evidencia.

```powershell
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/05_pruebas_base_datos.sql
```

Las pruebas pueden consumir valores de IDENTITY aun cuando se reviertan. Las claves externas nunca deben asociarse por el orden o la continuidad de esos números.

## Modelo

| Tabla | Clave interna | Identificación de origen |
| --- | --- | --- |
| Clientes | IdCliente int IDENTITY | IdExterno nvarchar(50), único y obligatorio |
| Productos | IdProducto int IDENTITY | IdExterno nvarchar(50), único y obligatorio |
| FuenteDatos | IdFuente int IDENTITY | IdExterno nvarchar(100), único y obligatorio |
| Opiniones | IdOpinion bigint IDENTITY | Canal + IdExterno nvarchar(50), combinación única |

Opiniones mantiene las FK a clientes, productos y fuentes; cliente es opcional. Conserva además IdClienteOrigen e IdProductoOrigen para no perder los códigos recibidos. Los canales admitidos son Web, Encuesta y RedSocial.

Clasificacion puede ser NULL mientras esté pendiente; cuando tenga valor, debe ser Positiva, Negativa o Neutra. PuntajeSatisfaccion admite NULL o valores de 1 a 5. Los comentarios, nombres, categorías e identificadores obligatorios no admiten texto vacío. No se añaden valores de sustitución a datos inválidos.

La aplicación resuelve correspondencias usando IdExterno y las claves internas devueltas por los procedimientos; carga catálogos antes que opiniones. BLL aplica la equivalencia académica C/P y los rechazos; los scripts no intentan deducir esas equivalencias.

## Contrato de los procedimientos

`usp_CargarCliente`, `usp_CargarProducto`, `usp_CargarFuente` y `usp_CargarOpinion` requieren una transacción abierta por el llamador. Devuelven la clave interna mediante un parámetro OUTPUT y un Estado:

| Estado | Significado |
| --- | --- |
| Insertado | Nueva clave de origen; fila insertada dentro de la transacción actual |
| Omitido | Misma clave y mismos valores; no se modifica |
| Conflicto | Misma clave con valores diferentes; no se sobrescribe |

Un Insertado solo se convierte en dato persistido cuando el llamador confirma la transacción. Un fallo de SQL debe provocar rollback y ajustar los conteos. Los procedimientos usan bloqueos sobre la búsqueda de la clave para proteger la comprobación e inserción; las restricciones UNIQUE también impiden duplicados.

Los textos se comparan con una collation binaria para distinguir contenido diferente, incluidos cambios de mayúsculas y acentos. La aplicación deberá validar longitudes y normalizar según las reglas acordadas antes de enviar parámetros; la existencia de un procedimiento no sustituye esas validaciones.

`usp_CargarOpinion` comprueba que la fuente tenga el tipo correspondiente al canal: Web → Web, Encuesta → CSV y RedSocial → Red Social. Las FK siguen siendo la garantía de existencia. La aplicación conserva las fuentes F importadas y enlaza opiniones a cinco fuentes técnicas con códigos ETL:canal:origen. DAL consulta sus metadatos con parámetros y bloqueos dentro de la misma transacción para reutilizar la fecha persistida.

`usp_ObtenerConteos` devuelve los totales actuales por tabla; no sustituye las métricas de una ejecución ETL.

## Vistas y verificación realizada

- `vw_OpinionesDetalle`: relaciones y procedencia; usa LEFT JOIN para no ocultar opiniones sin cliente.
- `vw_ResumenCargaPorCanal`: total, clasificadas y pendientes por canal. No presenta clasificación pendiente como Neutra.
- `vw_CalidadReferencial`: identifica posibles huérfanos por cada relación.

El 2026-10-23 se aplicaron los scripts sobre el modelo vacío y se probaron inserción, duplicados, conflictos, unicidad por canal, cliente opcional, clasificación pendiente, FK, rangos, transacción y compatibilidad de fuente con datos temporales revertidos.

Después se ejecutó la carga real desde .NET: 1206 filas CSV insertadas, 494 rechazadas y cinco fuentes técnicas aparte. La reejecución insertó cero y omitió las 1206 filas ya existentes y las cinco técnicas. Resultado comprobado: Clientes 500, Productos 200, FuenteDatos 105 y Opiniones 406 (200 Web, 200 RedSocial, seis Encuesta); 400 pendientes de clasificación. Las nueve consultas de 04_consultas_validacion.sql se ejecutaron; se comprobaron cero huérfanos, cero opiniones duplicadas y las tres FK habilitadas y confiables. Los conteos, las tablas pobladas, la ausencia de huérfanos y duplicados y el estado de las FK también se comprobaron mediante capturas reales de SSMS. La reejecución desde Visual Studio confirmó cero inserciones y los mismos rechazos. Los reportes, las capturas y el informe de entrega permanecen locales.
