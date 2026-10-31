# Base analítica: creación y verificación

`AnalisisOpinionesDW` es independiente de `AnalisisOpinionesClientes`. Los scripts crean cinco dimensiones y una tabla de hechos. No leen CSV, no copian datos transaccionales y no implementan conectores ni carga analítica.

## Requisitos y ejecución

Se comprobó SQL Server 17.0.1145.4 con `sqlcmd` y autenticación integrada. Se necesita una cuenta autorizada para crear bases y tablas. Los archivos se crean en las rutas predeterminadas de datos y log de la instancia, donde la cuenta del servicio SQL Server debe tener permiso de escritura. Revisar espacio disponible: los cuatro archivos reservan aproximadamente 256 MB iniciales, además del espacio de operación.

Desde la raíz del proyecto, ajustar el servidor y ejecutar en orden:

```powershell
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/01_crear_base_analitica.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/02_crear_tablas.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/03_verificar_modelo.sql
```

Comprobar el código de salida de cada comando antes de continuar; `-b` devuelve error al proceso si falla SQL. En SSMS, ejecutar cada archivo por separado y detenerse ante errores. No requieren modo SQLCMD ni variables SQLCMD. Ejecutarlos fuera de una transacción previa.

| Archivo | Operación |
| --- | --- |
| `01_crear_base_analitica.sql` | Crea base, archivos y grupos si la base no existe; si existe, verifica su configuración sin cambiarla. |
| `02_crear_tablas.sql` | Crea tablas, índices, restricciones y miembros técnicos en una transacción; al repetirse verifica el contrato de esquema v1. |
| `03_verificar_modelo.sql` | Verifica y muestra archivos, grupos, índices, LOB, PK, FK, CHECK, conteos y miembros técnicos, sin escribir datos. |
| `04_pruebas_integridad.sql` | Ejecuta 32 escenarios válidos e inválidos con registros temporales y rollback. |
| `05_vistas_analiticas.sql` | Crea o actualiza nueve vistas de indicadores; no modifica tablas ni carga filas. |
| `06_consultas_indicadores.sql` | Consulta indicadores y rankings, identificados con las preguntas de la actividad. Solo lectura. |
| `07_pruebas_indicadores.sql` | Comprueba cálculos con datos sintéticos y rollback; requiere una base sin opiniones y claves de prueba libres. |

La creación de la base y sus archivos es independiente de la transacción de tablas. Si falla el segundo archivo, la base puede quedar creada sin tablas: revisar el fallo y repetir los pasos, sin eliminar o recrear automáticamente la base.

## Almacenamiento esperado

| Grupo o archivo | Uso |
| --- | --- |
| `PRIMARY` | Archivo primario `AnalisisOpinionesDW_Primary` |
| `FG_Dimensiones`, predeterminado | Archivo `AnalisisOpinionesDW_Dimensiones`; cinco dimensiones y todos sus índices |
| `FG_Hechos` | Archivo `AnalisisOpinionesDW_Hechos`; HechoOpinion, índices y texto largo de Comentario |
| Log, fuera de filegroups | Archivo `AnalisisOpinionesDW_Log` |

Todos los archivos comienzan con 64 MB y crecimiento fijo de 64 MB. El tamaño inicial es una configuración para esta práctica, ajustable antes de la creación. Se usan `.mdf`/`.ndf` para datos y `.ldf` para log; los archivos físicos y respaldos no se publican.

Autogrowth queda como contingencia local, sin reemplazar la planificación y supervisión del espacio. Esto adapta la recomendación del material de clase de desactivarlo y ampliar archivos manualmente. Varios grupos sobre un SSD no demuestran una mejora de velocidad. No se configura RAID, particionamiento, tempdb ni otras bases.

## Esquema y reejecución

Tablas: `DimProducto`, `DimCliente`, `DimFecha`, `DimFuente`, `DimClasificacion` y `HechoOpinion`. Hay seis PK y cinco FK; la FK hacia fuente también exige que su canal coincida con el de la opinión.

Las dimensiones tienen índices agrupados por clave interna. HechoOpinion tiene PK no agrupada, índice agrupado por `FechaKey, OpinionKey` e índice por `ProductoKey, FechaKey` que incluye clasificación y puntaje. Proporcionan acceso por fecha y producto, sin atribuirles una mejora medida.

Identificadores de origen y valores controlados usan `Latin1_General_100_BIN2` para distinguir códigos y exigir los valores acordados. Las inserciones requieren las opciones de sesión del índice filtrado y las columnas calculadas: ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL y QUOTED_IDENTIFIER activadas; NUMERIC_ROUNDABORT desactivada. Los scripts ya las establecen.

La primera creación registra una huella SHA-256 de columnas, cálculos, identidades, valores predeterminados, índices, grupos, CHECK y FK en `ETL_ModeloAnalitico_v1`, una propiedad de base. Las siguientes ejecuciones comparan el esquema actual con ella. Las filas y los últimos valores consumidos de IDENTITY no forman parte de esa huella. No alterar la propiedad para eludir la comprobación.

Una estructura sin marca, incompleta o diferente requiere una migración revisada: no se reparan columnas, índices ni restricciones automáticamente. Un cambio intencional futuro del esquema deberá actualizar expresamente ese contrato. El primer script verifica el almacenamiento por separado.

## Pruebas y resultados comprobados

```powershell
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/04_pruebas_integridad.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/01_crear_base_analitica.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/02_crear_tablas.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/03_verificar_modelo.sql
```

Los 32 escenarios del archivo `04` comprueban hechos individuales del mismo cliente/producto/día, identificadores por canal, cliente desconocido, puntajes NULL y extremos, año bisiesto, asignación real de LOB, duplicados, referencias ausentes, incoherencias de fuente/canal y fecha, textos vacíos y reglas de catálogos. Son pruebas del esquema, no de la carga ETL ni de las fórmulas analíticas.

Las pruebas se detienen si sus claves o fechas reservadas ya existen, sin borrarlas. Cada caso revierte su transacción. Pueden consumir valores de IDENTITY aun con rollback; no asumir continuidad ni asociación con claves de origen. Revisar las claves de prueba antes de ejecutarlas sobre una base con datos operativos.

El 30 de octubre de 2026 se comprobaron creación, reejecución y 32 pruebas con SQL real. En una prueba controlada adicional se deshabilitó `CK_DimProducto_Textos`: la reejecución devolvió 51213; se restauró con `WITH CHECK CHECK` y la reejecución volvió a aprobar. Las cinco FK y los CHECK quedaron habilitados y confiables.

Resultado final: cero productos, fechas, fuentes y opiniones; un cliente técnico con clave 0 y cuatro clasificaciones (Pendiente, Positiva, Negativa y Neutra). No son registros de origen ni opiniones cargadas. Los conteos y huellas SHA-256 de datos y objetos transaccionales coincidieron antes y después.

## Consultas de indicadores

Después de crear y verificar las tablas, ejecutar:

```powershell
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/05_vistas_analiticas.sql
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/06_consultas_indicadores.sql
```

Las vistas agregan los hechos directamente por nivel. No almacenan resultados ni requieren refresco. El archivo `05` usa CREATE OR ALTER para actualizar sus definiciones; puede repetirse sin insertar datos. La huella v1 del archivo `02` sigue protegiendo las tablas, sus índices y restricciones; no incluye estas vistas.

| Vista | Uso |
| --- | --- |
| `vw_IndicadoresGenerales` | Total, puntajes, satisfacción y sentimientos del conjunto almacenado |
| `vw_IndicadoresProducto` | Métricas por producto, con suma y cantidad de puntajes para comparar promedios |
| `vw_IndicadoresFuente` | Métricas por fuente de origen y canal |
| `vw_IndicadoresCanal` | Comparación de los tres canales |
| `vw_IndicadoresCliente` | Comentarios y encuestas por cliente; desconocido identificado por separado |
| `vw_TendenciaMensual` | Año y mes |
| `vw_TendenciaTrimestral` | Año y trimestre |
| `vw_TendenciaProductoMensual` | Producto, año y mes |
| `vw_DistribucionClasificacion` | Cuatro estados, incluidos Pendiente y estados con cero comentarios |

`06_consultas_indicadores.sql` resuelve las preguntas Q01-Q10, Q13, Q15-Q16 y Q18-Q21. Estos códigos son referencias locales al orden de las 21 preguntas, no identificadores oficiales del profesor. Q01 cuenta opiniones aceptadas y almacenadas, no intentos ni rechazos de una ejecución ETL. Q11/Q12 siguen pendientes de datos de segmentación; Q14 necesita eventos/campañas y una relación verificable; Q17 es NLP opcional no implementado. El script informa esos límites sin inventar resultados.

El promedio considera exclusivamente los puntajes disponibles. El porcentaje de satisfacción es `100 × puntajes 4 o 5 / opiniones puntuadas`; este umbral es una definición adoptada para la entrega. Los porcentajes de sentimientos usan todas las opiniones del grupo como denominador y muestran cobertura y pendientes. Ninguna pendiente se convierte en Neutra ni se deduce sentimiento a partir del puntaje.

Sin opiniones, el resumen general devuelve conteos cero y porcentajes/promedios NULL. Sin puntajes, promedio y satisfacción son NULL. Las vistas agrupadas muestran grupos con opiniones; no crean periodos ni ganadores ficticios. El calendario incluye año para no mezclar meses de años diferentes. LAG compara periodos observados: si hay meses sin datos, no equivale necesariamente al mes inmediatamente anterior.

Los porcentajes se muestran con cuatro decimales y los promedios con seis. El redondeo puede hacer que porcentajes mostrados no sumen exactamente 100. Los rankings por conteo conservan empates con TOP WITH TIES. Los de promedio y proporción negativa comparan numeradores y denominadores antes de redondear, usando multiplicación decimal, para evitar falsos empates. No sumar porcentajes ni promediar promedios para calcular otro nivel: consultar la vista del nivel correspondiente o agregar los hechos.

Para comprobar los cálculos en la base de práctica sin opiniones:

```powershell
sqlcmd -S 'lpc:.' -E -b -f 65001 -i database/analitica/07_pruebas_indicadores.sql
```

Se verificaron 49 comprobaciones con SQL real el 30 de octubre de 2026: base vacía, grupos sin puntaje, todo pendiente, mezcla de canales, fuentes distintas, desconocidos, empates, años diferentes, tendencias y ponderación con muestras desiguales. Un escenario de precisión usa 4001 hechos temporales para comprobar valores que se muestran iguales tras el redondeo. También se ejecutaron las consultas originales del archivo `06` dentro de escenarios temporales y se verificaron los ganadores y empates observados.

El archivo `07` se detiene si hay opiniones o claves/fechas reservadas ocupadas; no limpia datos existentes. Sus inserciones, actualizaciones y borrados actúan sobre el escenario temporal dentro de la transacción, que se revierte por completo. Puede consumir valores de IDENTITY. SQL Server puede emitir el aviso de NULL omitido por una agregación: es esperable al contar y promediar datos opcionales; ANSI_WARNINGS permanece activado.

Tras las pruebas, las huellas de datos del DW coincidieron con las previas y quedaron cero opiniones. También coincidieron conteos y huellas de datos/objetos de la base transaccional. Las tablas conservan su contrato v1, índices y restricciones verificados. Los resultados de prueba no son resultados del conjunto académico cargado al DW: esa carga sigue pendiente y fuera de esta etapa.

## Entregables de modelado

Se prepararon por separado un DER en PDF horizontal A3, con fuentes editables SVG y Mermaid, y un documento breve de cuatro páginas en DOCX/PDF. El DER se contrastó con los metadatos reales: seis tablas, 33 columnas, cinco relaciones, claves compuestas y distribución en filegroups. El documento explica estructura, normalización, relaciones, almacenamiento, indicadores y las preguntas que necesitan datos adicionales.

Se revisaron las cinco páginas finales mediante imágenes renderizadas. El documento se exportó con Word como alternativa porque el renderizador no encontró LibreOffice. Las copias de los scripts de creación incluidas con los entregables se comprobaron idénticas a los archivos `01` y `02` de esta carpeta. Estos artefactos se entregan aparte del código; no se enlazan archivos locales desde el repositorio.

Los tres tipos de entregables de la actividad están preparados, con las limitaciones de datos ya descritas. Esto no supone que se hayan implementado conectores externos o una carga analítica, ni que se hayan obtenido resultados reales de segmentación o campañas.
