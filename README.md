# Sistema de Análisis de Opiniones de Clientes

Proyecto académico de **Electiva I, ITLA**, orientado a integrar y analizar opiniones de clientes mediante un proceso ETL: extracción, transformación y carga de datos.

El sistema se desarrollará por etapas durante el cuatrimestre. Cada etapa tendrá un alcance definido, verificaciones y documentación de lo que realmente se haya implementado.

## Entrega actual

Implementar una aplicación que cargue automáticamente los CSV del proyecto en una base de datos transaccional, respetando las relaciones del modelo.

La carga deberá:

- Validar la estructura de los archivos, campos obligatorios, formatos y tipos de datos.
- Limpiar o transformar los datos cuando corresponda.
- Detectar duplicados y validar las referencias antes de insertar registros.
- Mantener la integridad mediante claves primarias y foráneas.
- Manejar errores mediante excepciones.
- Mostrar registros procesados, insertados y rechazados, junto con un resumen final.

La entrega incluirá scripts de creación de la base de datos, tablas, restricciones, procedimientos almacenados y vistas; evidencias de ejecución y tablas pobladas; y al menos cinco consultas SQL de validación.

## Arquitectura acordada

La aplicación se desarrollará en C#/.NET con cuatro capas:

| Capa | Responsabilidad |
| --- | --- |
| **Entities** | Representar las entidades y los resultados del proceso. |
| **DAL** | Acceder a SQL Server y ejecutar operaciones de persistencia. |
| **BLL** | Coordinar la carga y aplicar validaciones, transformaciones y reglas de duplicados. |
| **Consola** | Iniciar el proceso y presentar su resultado. |

Los lectores de archivos, las validaciones y la persistencia tendrán responsabilidades separadas para facilitar las pruebas y la incorporación de nuevas fuentes. La consola forma parte de las cuatro capas.

## Estado actual

El proyecto contiene una [solución de cuatro capas](SistemaAnalisisOpiniones.sln) en .NET 10 y los [scripts de base de datos](database/README.md), con cuatro tablas, procedimientos de carga, vistas y consultas de validación. Los scripts SQL se comprobaron con registros temporales que se revirtieron.

ETL.Entities incluye los modelos, resultados y contratos de sesión transaccional. DAL los implementa con Microsoft.Data.SqlClient y los procedimientos SQL existentes; BLL coordina catálogos, fuentes técnicas y opiniones sin depender de SqlClient.

**La consola valida los seis CSV con `--validar` y los carga en SQL Server con `--cargar`.** Comprueba estructura, campos, formatos, duplicados y referencias; genera resumen por archivo y reporte JSON local. La carga confirma el conjunto válido en una transacción y revierte ante errores técnicos previos a la confirmación.

La primera carga real del conjunto académico confirmó 1206 filas CSV y cinco fuentes técnicas adicionales; rechazó 494 filas. La segunda carga confirmó cero inserciones y 1206 omisiones, con los mismos rechazos. La base quedó con 500 clientes, 200 productos, 105 fuentes y 406 opiniones; 400 opiniones web/redes siguen sin clasificación. Se comprobaron las relaciones y la ausencia de duplicados. La reejecución con --cargar se comprobó desde Visual Studio, con estado Confirmada y código de salida 2 por los rechazos esperados. Se prepararon capturas reales de ejecución, tablas pobladas y consultas SQL, junto con un informe de entrega; estas evidencias permanecen locales.

El entorno de código acordado es Visual Studio. Para net10.0 se requiere Visual Studio 2026 18.0 o posterior; la apertura, compilación y ejecución inicial se comprobaron en Community 2026 estable 18.11.1, con cuatro proyectos compilados y salida 0.

## Flujo de trabajo con Git

- `main` mantiene los cambios integrados y verificados.
- `feature/<tema>` incorpora funcionalidades; `fix/<tema>` corrige errores; `docs/<tema>` actualiza documentación.
- Cada commit tiene un solo propósito. Los cambios de código y documentación se registran por separado.
- Los mensajes usan prefijos como `feat:`, `fix:`, `docs:` o `refactor:` y describen el cambio de forma breve.
- Antes de cada commit se revisan los archivos seleccionados, `git diff --cached` y `git diff --cached --check`.
- Los cambios se integran mediante pull requests usando un merge que conserve los commits individuales.
- Cada PR explica el problema, el cambio y la validación realizada.

Los archivos compilados, la configuración personal, los secretos, los archivos físicos de SQL Server y los temporales quedan excluidos mediante `.gitignore`. Los datos de entrada, documentos de terceros y evidencias se revisarán antes de publicarlos.

## Próximos pasos

1. Presentar el proyecto, los scripts y las evidencias de la carga transaccional según el mandato.
2. Definir con el material del profesor la siguiente unidad del proyecto.

## Ejecutar la validación

Requisitos: SDK .NET 10 estable; Visual Studio 2026 para trabajar desde el IDE. Desde la raíz:

```powershell
dotnet restore SistemaAnalisisOpiniones.sln
dotnet run --project src/ETL.Consola/ETL.Consola.csproj -- --validar "ruta-a-la-carpeta-con-los-seis-csv"
```

La carpeta debe contener clients.csv, products.csv, fuente_datos.csv, web_reviews.csv, surveys_part1.csv y social_comments.csv. Los archivos se proporcionan aparte y no forman parte del repositorio público. Sin argumentos, la consola muestra ayuda.

Los encabezados se comparan por nombre exacto, incluidos acentos, y pueden cambiar de orden. Se exige UTF-8, con o sin BOM. Las fechas usan yyyy-MM-dd y los puntajes enteros 1–5. Se omiten duplicados idénticos dentro de cada archivo y se rechazan conflictos, manteniendo la primera fila válida. Durante la carga también se comprueban los duplicados contra SQL Server mediante los procedimientos.

Las referencias C/P se convierten a los identificadores numéricos externos de los catálogos como supuesto académico de este conjunto, conservando los códigos originales. Cliente vacío se admite como opcional; uno informado pero ausente se rechaza. La clasificación web/redes queda pendiente. Una fila con varios motivos cuenta como un solo rechazo.

Los reportes se guardan en reportes-locales/, excluida de Git, y contienen archivo, registro, línea y motivos, sin copiar nombres, correos o comentarios. Un archivo ausente, codificación inválida, encabezado incorrecto o CSV mal formado marca la ejecución como incompleta; sus filas no se suman al total. Los totales de los demás archivos no equivalen a una validación completa del conjunto.

| Código de salida | Significado |
| --- | --- |
| 0 | Validación o carga completa sin rechazos, o ayuda |
| 2 | Validación completa o carga confirmada con registros rechazados |
| 1 | Argumentos, archivo o reporte impiden completar la operación |
| 130 | Cancelación solicitada |

## Ejecutar pruebas

```powershell
dotnet test --solution SistemaAnalisisOpiniones.sln --configuration Release
```

El proyecto tests/ETL.Tests usa xUnit y Microsoft.Testing.Platform, seleccionado en global.json para el SDK .NET 10. Es un proyecto de pruebas, no una quinta capa. Sin configuración SQL, las seis pruebas de integración se omiten explícitamente; las otras 69 usan datos sintéticos y no necesitan los originales. Con ETL_SQL_CONNECTION y una base preparada se ejecutan las 75 pruebas. Las pruebas SQL revierten sus datos temporales; pueden consumir valores de IDENTITY. No hay pipeline ni requisito de cobertura.

## Ejecutar la carga SQL

Preparar primero la base con los [scripts SQL](database/README.md). En la misma terminal donde se ejecutará la aplicación, configurar la conexión autorizada mediante una variable de entorno:

```powershell
$env:ETL_SQL_CONNECTION = "Server=SERVIDOR;Database=AnalisisOpinionesClientes;Integrated Security=True;Encrypt=True;"
dotnet run --project src/ETL.Consola/ETL.Consola.csproj -- --cargar "ruta-a-la-carpeta-con-los-seis-csv"
```

Ajustar el servidor y la configuración del certificado al entorno. No guardar contraseñas ni cadenas privadas en el código, perfiles compartidos, reportes o commits. La variable de una terminal no se transfiere a un Visual Studio que ya estaba abierto; configurarla para el proceso del IDE al probar desde allí.

La aplicación valida primero y no inicia SQL si un archivo tiene un fallo estructural. Carga clientes, productos, las 100 fuentes importadas, cinco fuentes técnicas y opiniones. Las fuentes técnicas representan web_reviews, EncuestaInterna, Instagram, Twitter y Facebook; reutilizan la fecha guardada y se cuentan aparte de las 1700 entradas CSV. Las claves internas devueltas por SQL resuelven las relaciones; no se supone que coincidan con los identificadores externos.

Una clave existente con valores iguales se omite; con valores distintos se rechaza, sin actualizaciones ni borrados automáticos. Las opiniones dependientes de un maestro o fuente técnica en conflicto se rechazan también. El código de salida 2 indica una carga confirmada con rechazos, no un fallo técnico.

El reporte carga-*.json distingue Confirmada, Revertida, NoIniciada e Indeterminada. Solo Confirmada informa inserciones confirmadas; las filas no confirmadas quedan pendientes. Si se pierde la respuesta del COMMIT, el resultado es Indeterminada y requiere reconciliar la base antes de repetir. No se realizan reintentos automáticos. El reporte se abre antes de iniciar SQL para comprobar acceso; si falla su escritura después del COMMIT, se informa el estado de carga conocido sin afirmar que los datos se revirtieron.

El proyecto completo contempla otras fuentes de datos, análisis de opiniones, ejecución mediante Worker Service y visualizaciones. Su implementación se definirá en etapas posteriores.
