# Guía de estudio: base transaccional para la carga ETL

Unidad: preparación de la base de datos. Fecha: 2026-10-23.

## Objetivo

Explicar cómo el modelo conserva el origen de los datos, protege sus relaciones y permite repetir una carga sin sobrescribir registros. Esta unidad comprende SQL; la aplicación .NET y la carga CSV quedan para la siguiente etapa.

## Recorrido de lectura

| Orden | Archivo | Qué investigar al leerlo |
| --- | --- | --- |
| 1 | [Esquema](../database/01_crear_base_datos.sql) | Cuatro tablas, claves internas, identificadores externos, índices y restricciones |
| 2 | [Procedimientos](../database/02_procedimientos.sql) | Parámetros, estados de carga, transacción del llamador y comparación de contenido |
| 3 | [Vistas](../database/03_vistas.sql) | Detalle relacionado, cliente opcional y clasificación pendiente |
| 4 | [Consultas](../database/04_consultas_validacion.sql) | Qué evidencia aporta cada consulta y qué no demuestra |
| 5 | [Pruebas SQL](../database/05_pruebas_base_datos.sql) | Casos válidos, errores esperados y reversión de datos temporales |
| 6 | [Instrucciones](../database/README.md) | Orden de ejecución y contrato que usará la aplicación |

## Temas para investigar

- Diferencia entre PK, FK, índice UNIQUE e IDENTITY.
- Clave interna frente a identificador externo; identificación de una opinión por canal y código.
- NULL frente a cero, texto vacío y clasificación Neutra.
- Transacciones explícitas, COMMIT, ROLLBACK, XACT_ABORT y THROW.
- Diferencia entre un duplicado idéntico y un conflicto de contenido.
- Efectos de la collation al comparar texto y de los bloqueos al buscar una clave antes de insertar.
- LEFT JOIN frente a INNER JOIN cuando una relación es opcional.

## Decisiones de diseño para explicar

1. Localiza dónde se evita depender de la secuencia de IDENTITY para relacionar los archivos.
2. Explica por qué conservar IdExterno no reemplaza las claves foráneas internas.
3. Revisa por qué una opinión puede quedar sin clasificación y cómo la vista la contabiliza.
4. Sigue el recorrido de una clave repetida: búsqueda, comparación y estado devuelto. Señala qué permanece sin modificar.
5. Describe qué responsabilidad tendrá el llamador sobre la transacción y por qué Insertado no significa todavía confirmado.
6. Identifica qué problema cubren las restricciones UNIQUE y qué protección adicional buscan los bloqueos usados en los procedimientos.

## Arquitectura, SOLID y patrones

En esta unidad existen esquema, procedimientos, vistas y pruebas SQL. Las cuatro capas C# están acordadas, pero todavía no se han implementado; tampoco hay interfaces o inyección de dependencias que puedan presentarse como realizadas.

Investiga cómo distribuirías responsabilidades entre Entities, DAL, BLL y consola cuando se construyan. Formula una propuesta y compárala después con el código real. No atribuyas Repository, Unit of Work u otros patrones al proyecto solo porque existan procedimientos o transacciones.

Preguntas para conectar ambas etapas:

- ¿Qué debería validar C# antes de llamar a un procedimiento y qué debe seguir garantizando SQL Server?
- ¿En qué capa colocarías la regla académica de equivalencia de códigos y por qué?
- ¿Quién decidiría confirmar o revertir una ejecución? ¿Qué información necesitaría para hacerlo?

## Preguntas de autoexplicación

- ¿Puede haber dos opiniones con el mismo IdExterno? Revisa las condiciones del índice antes de responder.
- ¿Por qué los números de IDENTITY pueden tener saltos después de una prueba con rollback?
- ¿Qué diferencia hay entre cero filas huérfanas en una base vacía y una carga real correctamente relacionada?
- ¿Qué pasa si una misma clave llega con un comentario diferente? ¿Dónde lo compruebas?
- ¿Por qué una opinión sin cliente no debería desaparecer de la vista de detalle?
- ¿Qué evita que un canal Web use una fuente de tipo CSV?
- ¿Los conteos de tablas equivalen a procesados, insertados y rechazados de una ejecución? Justifica la diferencia.

## Ejercicios breves

Trabaja con datos temporales dentro de una transacción que reviertas; no alteres los CSV originales ni conserves datos de ensayo como evidencia de carga real.

1. Dibuja las cuatro tablas, marca PK/FK y señala las relaciones opcionales.
2. Predice el estado al cargar dos veces un cliente idéntico y una tercera vez con nombre distinto. Comprueba tu predicción con el procedimiento.
3. Diseña un caso inválido para cada FK. Explica cómo comprobarías que la prueba falló por la relación que querías estudiar.
4. Propón una consulta que reconcilie opiniones clasificadas y pendientes con el total por canal.
5. Modifica una copia local de una prueba para comparar NULL con texto vacío. Describe el resultado observado sin asumir que representan lo mismo.
6. Redacta en cinco líneas qué falta para demostrar el cumplimiento de la asignación completa de carga.

## Lecturas oficiales

Enlaces consultados el 2026-10-23; úsales para investigar, no para copiar definiciones completas en la defensa.

- [Claves primarias y foráneas](https://learn.microsoft.com/en-us/sql/relational-databases/tables/primary-and-foreign-key-constraints?view=sql-server-ver17): relaciona las garantías de integridad con el esquema.
- [Transacciones en Transact-SQL](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql?view=sql-server-ver17): sigue la diferencia entre cambios pendientes y confirmados.
- [SET XACT_ABORT](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-xact-abort-transact-sql?view=sql-server-ver17): revisa qué errores afectan a una transacción y qué límites tiene esta opción.

## Criterio de cierre de esta unidad

Debes poder explicar el esquema, recorrer una inserción, distinguir duplicado de conflicto y demostrar una validación con datos temporales revertidos. Haber terminado esta unidad no significa que ya exista la aplicación ETL ni que los CSV estén cargados.
