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

ETL.Entities incluye los modelos Cliente, Producto, FuenteDatos y Opinion, el resultado tipado de persistencia y los contratos de sesión transaccional. Todavía no hay implementaciones de esos contratos.

**La consola lee y valida los seis CSV mediante `--validar`; todavía no inserta datos en SQL Server.** Comprueba estructura, campos, formatos, duplicados y referencias contra los catálogos CSV. Genera un resumen por archivo y un reporte JSON local de rechazos. La persistencia y sus contratos todavía no tienen implementación .NET.

La validación local del conjunto académico produjo 1700 filas procesadas, 1206 aptas, 494 rechazadas y cero omitidas. Son resultados de validación, no inserciones. Las pruebas automatizadas usan datos sintéticos y no necesitan SQL Server ni los CSV originales.

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

1. Probar el modo de validación desde Visual Studio.
2. Proponer e implementar los contratos de persistencia con los procedimientos y su transacción.
3. Ejecutar la carga y comprobar conteos, segunda ejecución, manejo de fallos y evidencias reales.

## Ejecutar la validación

Requisitos: SDK .NET 10 estable; Visual Studio 2026 para trabajar desde el IDE. Desde la raíz:

```powershell
dotnet restore SistemaAnalisisOpiniones.sln
dotnet run --project src/ETL.Consola/ETL.Consola.csproj -- --validar "ruta-a-la-carpeta-con-los-seis-csv"
```

La carpeta debe contener clients.csv, products.csv, fuente_datos.csv, web_reviews.csv, surveys_part1.csv y social_comments.csv. Los archivos se proporcionan aparte y no forman parte del repositorio público. Sin argumentos, la consola muestra ayuda.

Los encabezados se comparan por nombre exacto, incluidos acentos, y pueden cambiar de orden. Se exige UTF-8, con o sin BOM. Las fechas usan yyyy-MM-dd y los puntajes enteros 1–5. Se omiten duplicados idénticos dentro de cada archivo y se rechazan conflictos, manteniendo la primera fila válida. La comprobación de duplicados contra SQL Server corresponderá a la persistencia.

Las referencias C/P se convierten a los identificadores numéricos externos de los catálogos como supuesto académico de este conjunto, conservando los códigos originales. Cliente vacío se admite como opcional; uno informado pero ausente se rechaza. La clasificación web/redes queda pendiente. Una fila con varios motivos cuenta como un solo rechazo.

Los reportes se guardan en reportes-locales/, excluida de Git, y contienen archivo, registro, línea y motivos, sin copiar nombres, correos o comentarios. Un archivo ausente, codificación inválida, encabezado incorrecto o CSV mal formado marca la ejecución como incompleta; sus filas no se suman al total. Los totales de los demás archivos no equivalen a una validación completa del conjunto.

| Código de salida | Significado |
| --- | --- |
| 0 | Validación completa sin rechazos, o ayuda |
| 2 | Validación completa con registros rechazados |
| 1 | Argumentos, archivo o reporte impiden completar la operación |
| 130 | Cancelación solicitada |

## Ejecutar pruebas

```powershell
dotnet test --solution SistemaAnalisisOpiniones.sln --configuration Release
```

El proyecto tests/ETL.Tests usa xUnit y Microsoft.Testing.Platform, seleccionado en global.json para el SDK .NET 10. Es un proyecto de pruebas, no una quinta capa de la aplicación. No hay pipeline ni requisito de cobertura.

El proyecto completo contempla otras fuentes de datos, análisis de opiniones, ejecución mediante Worker Service y visualizaciones. Su implementación se definirá en etapas posteriores.
