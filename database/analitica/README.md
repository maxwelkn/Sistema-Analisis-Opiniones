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

Se comprueban hechos individuales del mismo cliente/producto/día, identificadores por canal, cliente desconocido, puntajes NULL y extremos, año bisiesto, asignación real de LOB, duplicados, referencias ausentes, incoherencias de fuente/canal y fecha, textos vacíos y reglas de catálogos. Son pruebas del esquema, no de la carga ETL ni de las fórmulas analíticas.

Las pruebas se detienen si sus claves o fechas reservadas ya existen, sin borrarlas. Cada caso revierte su transacción. Pueden consumir valores de IDENTITY aun con rollback; no asumir continuidad ni asociación con claves de origen. Revisar las claves de prueba antes de ejecutarlas sobre una base con datos operativos.

El 30 de octubre de 2026 se comprobaron creación, reejecución y 32 pruebas con SQL real. En una prueba controlada adicional se deshabilitó `CK_DimProducto_Textos`: la reejecución devolvió 51213; se restauró con `WITH CHECK CHECK` y la reejecución volvió a aprobar. Las cinco FK y los CHECK quedaron habilitados y confiables.

Resultado final: cero productos, fechas, fuentes y opiniones; un cliente técnico con clave 0 y cuatro clasificaciones (Pendiente, Positiva, Negativa y Neutra). No son registros de origen ni opiniones cargadas. Los conteos y huellas SHA-256 de datos y objetos transaccionales coincidieron antes y después.

El DER final, el documento de entrega y las consultas de indicadores corresponden a los siguientes bloques. Este resultado no equivale al cierre completo de la actividad.
