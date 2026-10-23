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

ETL.Entities incluye los modelos Cliente, Producto, FuenteDatos y Opinion, el resultado tipado de persistencia y los contratos de sesión transaccional. Su alcance está descrito en [entidades y contratos de carga](docs/entidades-contratos-carga.md); todavía no hay implementaciones de esos contratos.

**La consola ejecuta únicamente el mensaje inicial de la estructura; todavía no realiza una carga CSV.** La solución compila con cero advertencias y cero errores por terminal. El esquema SQL adapta el modelo previo con identificadores externos, unicidad por origen y clasificación pendiente.

El entorno de código acordado es Visual Studio. Para net10.0 se requiere Visual Studio 2026 18.0 o posterior; la apertura, compilación y ejecución inicial se comprobaron en Community 2026 estable 18.11.1, con cuatro proyectos compilados y salida 0. Consulta las [instrucciones de Visual Studio y ejecución](docs/desarrollo-visual-studio.md).

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

1. Implementar lectura CSV, correspondencias, validaciones y reporte de rechazos conforme a las reglas acordadas.
2. Implementar los contratos de persistencia con los procedimientos y su transacción.
3. Ejecutar los CSV y comprobar conteos, segunda ejecución, manejo de fallos y evidencias reales.

El proyecto completo contempla otras fuentes de datos, análisis de opiniones, ejecución mediante Worker Service y visualizaciones. Su implementación se definirá en etapas posteriores.
