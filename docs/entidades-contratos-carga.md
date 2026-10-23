# Entidades y contratos de carga

Esta etapa define los datos que recibirá la persistencia y su contrato transaccional. No implementa lectura CSV, validaciones, conexión SQL ni métricas finales. Los tipos están en ETL.Entities y no incorporan paquetes externos.

## Datos de entrada a persistencia

| Tipo | Datos | Correspondencia SQL |
| --- | --- | --- |
| Cliente | IdExterno, Nombre, Email opcional | usp_CargarCliente |
| Producto | IdExterno, Nombre, Categoria | usp_CargarProducto |
| FuenteDatos | IdExterno, TipoFuente, FechaCarga | usp_CargarFuente |
| Opinion | Origen, canal, referencias internas, fecha, comentario, clasificación y puntaje opcionales | usp_CargarOpinion |

Los records son contenedores de valores con propiedades de inicialización. No representan filas CSV crudas ni cargan datos por sí mismos. Las claves IDENTITY de los nuevos registros se obtendrán del resultado de persistencia; no se incluyen como claves asignadas por el CSV. Opinion recibe referencias internas ya resueltas y conserva IdClienteOrigen e IdProductoOrigen para trazabilidad.

Las decisiones de tipos se basan en [el esquema](../database/01_crear_base_datos.sql) y [los procedimientos](../database/02_procedimientos.sql):

- Los identificadores externos y de origen son string; no se eliminan prefijos ni ceros en estos modelos. La futura conversión C/P aplicará el supuesto académico aprobado, conservando los códigos de origen y resolviendo las claves internas por correspondencias.
- Las claves de catálogos son int; la clave devuelta para una opinión es long, equivalente a bigint. Un cliente ausente en una opinión se representa con int?, sin sustituirlo por cero.
- Email, clasificación, puntaje y código de cliente de origen admiten null conforme al esquema. Un valor de cliente informado pero inexistente deberá rechazarse antes de persistir; no se convierte a null para evitar una FK.
- Las fechas son DateTime porque el destino es datetime2(0), sin zona horaria. El lector validará el formato de origen y la persistencia deberá respetar la precisión de segundos; estos tipos no inventan una fecha ni convierten zonas horarias.
- El puntaje es byte?, por tinyint. Este tipo no garantiza el rango 1–5: esa validación sigue pendiente en BLL y el CHECK de SQL se mantiene como protección adicional.
- Canal, TipoFuente y Clasificacion permanecen como texto compatible con SQL. La futura validación limitará los valores a los admitidos; construir un record no implica que sus datos sean válidos. Longitudes, campos obligatorios y normalizaciones tampoco se validan todavía.

No se añaden atributos de ORM, lógica de consola ni métodos de acceso a datos. No se duplica el esquema mediante modelos para una API o un dashboard que todavía no existen.

## Resultado de una operación

ResultadoPersistencia<TId> contiene la clave interna devuelta y EstadoPersistencia. El parámetro de tipo conserva int para catálogos y long para opiniones sin duplicar el contenedor. No es un repositorio genérico.

| Estado | Significado del procedimiento |
| --- | --- |
| Insertado | Registro creado dentro de la transacción todavía pendiente de confirmación |
| Omitido | Misma clave externa y valores iguales al registro existente |
| Conflicto | Misma clave externa con contenido distinto; no se actualiza ni elimina |

Los nombres coinciden con las salidas SQL. La implementación DAL deberá traducirlas explícitamente y fallar ante un estado desconocido, sin asumir éxito. El valor predeterminado numérico 0 del enum no corresponde a ninguno de esos estados.

Este resultado no representa rechazos de formato ni el resumen completo de una ejecución. Tras un rollback, las inserciones revertidas no pueden aparecer como confirmadas en las métricas finales. Un conflicto devuelve la clave existente para diagnóstico, pero eso no autoriza tratar la fila conflictiva como válida ni continuar dependencias que usen sus valores rechazados.

## Sesión transaccional

IFabricaSesionCarga permite que la coordinación obtenga una ISesionCarga sin conocer SqlConnection o SqlTransaction. La consola conectará la fábrica de DAL con la coordinación de BLL cuando existan sus implementaciones. Estas interfaces no implementan aún inyección ni acceso a SQL.

La implementación futura debe cumplir este ciclo:

1. AbrirAsync abre una conexión e inicia una transacción antes de devolver la sesión; si falla, libera los recursos adquiridos y propaga el error.
2. Los cuatro métodos Cargar usan esa misma conexión y transacción. Cargar catálogos antes de opiniones y conservar las claves devueltas para resolver referencias; no asumir que IDENTITY coincide con IdExterno.
3. ConfirmarAsync confirma únicamente cuando el coordinador termina la carga válida. La implementación debe impedir operaciones posteriores al cierre de la transacción.
4. RevertirAsync revierte la transacción activa ante un fallo técnico. La limpieza debe ser posible aunque se haya cancelado la operación inicial.
5. DisposeAsync libera recursos y revierte cualquier transacción todavía pendiente. Liberar una sesión nunca confirma automáticamente.

La sesión no se comparte entre corridas ni se utiliza concurrentemente. Si se produce un fallo técnico, la coordinación abortará la corrida; los rechazos de datos y los conflictos se gestionarán según las reglas aprobadas, sin sobrescrituras. CancellationToken permite solicitar cancelación sin introducir un scheduler o un Worker Service.

La necesidad de una transacción del llamador ya está impuesta por los procedimientos. Agrupar esas operaciones en una sesión resuelve ese requisito concreto; no se crean interfaces por cada entidad ni una nueva capa. Los contratos podrán ampliarse cuando el lector, las correspondencias persistidas o las fuentes técnicas requieran una operación demostrable.

## Comprobación y alcance pendiente

Compilar con `dotnet build SistemaAnalisisOpiniones.sln --configuration Release`. Revisar que tipos, opcionalidad y parámetros coincidan con los scripts SQL. Esta comprobación valida la compilación de las declaraciones; no demuestra comportamiento transaccional ni validación de entradas.

No se añade framework de pruebas para contenedores de datos e interfaces sin implementación. Las pruebas de conversión, validación, rollback y reejecución corresponderán al código que implemente esas conductas. La consola conserva sus dos mensajes iniciales hasta que exista el coordinador de carga.
