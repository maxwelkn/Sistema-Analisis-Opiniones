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

El repositorio contiene la configuración inicial de Git y esta documentación. **Todavía no hay una solución .NET, una aplicación ejecutable ni una carga de datos implementada aquí.**

Existe un modelo previo de la asignatura fuera de este repositorio. Se revisará su correspondencia con los CSV antes de adaptar el esquema o implementar la carga.

La versión de .NET y las instrucciones de instalación, conexión y ejecución se documentarán cuando se haya definido y comprobado la aplicación.

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

1. Acordar cómo corresponden los identificadores de los CSV con el modelo relacional.
2. Definir el tratamiento de referencias inexistentes, campos opcionales, duplicados y ejecuciones repetidas.
3. Precisar el esquema transaccional, los procedimientos y las vistas necesarios para esta entrega.
4. Crear la solución de cuatro capas e implementar la carga por etapas.
5. Comprobar los resultados y preparar las consultas SQL y evidencias.

El proyecto completo contempla otras fuentes de datos, análisis de opiniones, ejecución mediante Worker Service y visualizaciones. Su implementación se definirá en etapas posteriores.
