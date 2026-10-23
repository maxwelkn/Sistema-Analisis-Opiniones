# Desarrollo con Visual Studio

## Requisitos y compatibilidad

La solución usa .NET 10 y está preparada para Visual Studio 2026, versión 18.0 o posterior, con las herramientas de desarrollo de .NET instaladas. Microsoft documenta que el destino net10.0 requiere esa versión del IDE: [compatibilidad de SDK, MSBuild y Visual Studio](https://learn.microsoft.com/en-us/dotnet/core/porting/versioning-sdk-msbuild-vs).

En el diagnóstico del 2026-10-23 se encontró Visual Studio Community 2022 17.14.37 y el SDK independiente 10.0.303. Este SDK permitió compilar por terminal, pero no convierte Visual Studio 2022 en un entorno compatible para desarrollar y depurar net10.0. La apertura y depuración en Visual Studio 2026 todavía no se han comprobado en este equipo.

Para preparar el IDE, instalar Visual Studio 2026 desde la [página oficial](https://visualstudio.microsoft.com/downloads/) y seleccionar las herramientas para desarrollo de escritorio de .NET. No hace falta instalar herramientas web, Azure o contenedores para esta consola. Conservar las instalaciones existentes si otras asignaturas las necesitan.

`global.json` selecciona un SDK estable de la familia .NET 10. La versión base es 10.0.100 y rollForward latestFeature permite usar una banda instalada posterior de esa misma familia; no fuerza instalar exactamente esa versión ni acepta SDK preview. Mantener actualizado el SDK que acompaña al IDE.

## Abrir y ejecutar

1. Abrir Visual Studio 2026 y seleccionar **Abrir un proyecto o una solución**.
2. Seleccionar [SistemaAnalisisOpiniones.sln](../SistemaAnalisisOpiniones.sln) en la raíz del repositorio.
3. Verificar que el Explorador de soluciones muestre ETL.Entities, ETL.DAL, ETL.BLL y ETL.Consola dentro de src.
4. Establecer **ETL.Consola como proyecto de inicio** desde su menú contextual.
5. Compilar la solución. NuGet puede restaurar los activos del SDK; esta etapa no agrega paquetes externos.
6. Ejecutar sin depuración para comprobar el mensaje inicial, o usar F5 para depurar cuando el IDE esté preparado.

El archivo sln fue generado por dotnet. Los números de versión del encabezado generado no sustituyen los requisitos de net10.0; no modificar ese encabezado para intentar habilitar Visual Studio 2022.

La salida actual identifica la estructura inicial y avisa que la carga CSV se implementará en la siguiente etapa. No se ejecutan scripts SQL ni se modifican datos desde la consola inicial.

## Proyectos y referencias

| Proyecto | Responsabilidad prevista | Referencias actuales |
| --- | --- | --- |
| ETL.Entities | Entidades, resultados y contratos puros necesarios | Ningún proyecto |
| ETL.DAL | Persistencia y sesión transaccional con SQL Server | ETL.Entities |
| ETL.BLL | Lectores aislados, validaciones y coordinación de la carga | ETL.Entities |
| ETL.Consola | Configuración, composición y presentación del proceso | ETL.Entities, ETL.BLL y ETL.DAL |

Las tres bibliotecas están inicialmente sin clases de negocio. Se retiraron las clases vacías Class1 de las plantillas porque no representan ninguna responsabilidad del proyecto. Se añadirán entidades y contratos cuando se implemente la carga.

BLL no referencia DAL: la coordinación consumirá contratos puros y la consola conectará las implementaciones. Estas referencias preparan la separación de responsabilidades; todavía no hay interfaces ni inyección de dependencias implementadas.

## Verificación por terminal

Desde la raíz del repositorio:

```powershell
dotnet restore SistemaAnalisisOpiniones.sln
dotnet build SistemaAnalisisOpiniones.sln --configuration Release --no-restore
dotnet run --project src/ETL.Consola/ETL.Consola.csproj --configuration Release --no-build
```

El 2026-10-23 se ejecutaron estos comandos con el SDK 10.0.303: restauración correcta, build con cero advertencias y cero errores, y salida inicial de consola correcta. Es una comprobación de estructura, no una prueba de lectura, validación, conexión ni carga de CSV.

Los directorios bin y obj y la configuración personal de Visual Studio están excluidos de Git. Las selecciones personales del IDE no deben incorporarse a los commits del código.

## Siguiente implementación

Crear entidades de entrada y resultados, definir contratos necesarios, implementar lectura CSV y validaciones, conectar los procedimientos SQL y ejecutar la carga. Las herramientas y paquetes externos se incorporarán cuando se utilicen, con versiones compatibles y verificación correspondiente.
