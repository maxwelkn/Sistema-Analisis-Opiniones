USE AnalisisOpinionesDW;

IF @@TRANCOUNT <> 0
BEGIN
    RAISERROR(N'La carga requiere una sesión sin transacción abierta.', 16, 1);
    RETURN;
END;

SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

DECLARE @resultado TABLE
(
    Dimension sysname PRIMARY KEY,
    Esperadas int NOT NULL,
    Insertadas int NOT NULL
);

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @bloqueo int;
    EXEC @bloqueo = sys.sp_getapplock
        @Resource = N'CargaDimensionesOpiniones',
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 10000;

    IF @bloqueo < 0
        THROW 51300, N'No se pudo obtener el bloqueo de carga de dimensiones.', 1;

    SELECT IdExterno COLLATE Latin1_General_100_BIN2 AS IdProductoOrigen, Nombre, Categoria
    INTO #Productos
    FROM AnalisisOpinionesClientes.dbo.Productos;

    SELECT IdExterno COLLATE Latin1_General_100_BIN2 AS IdClienteOrigen, Nombre
    INTO #Clientes
    FROM AnalisisOpinionesClientes.dbo.Clientes;

    SELECT DISTINCT CONVERT(date, Fecha) AS Fecha
    INTO #Fechas
    FROM AnalisisOpinionesClientes.dbo.Opiniones;

    IF EXISTS
    (
        SELECT 1
        FROM AnalisisOpinionesClientes.dbo.Opiniones AS o
        LEFT JOIN AnalisisOpinionesClientes.dbo.FuenteDatos AS f ON f.IdFuente = o.IdFuente
        WHERE f.IdFuente IS NULL
    )
        THROW 51301, N'Hay opiniones con una fuente ausente en el origen.', 1;

    SELECT DISTINCT f.IdExterno COLLATE Latin1_General_100_BIN2 AS IdFuenteOrigen,
                    o.Canal COLLATE Latin1_General_100_BIN2 AS Canal,
                    f.TipoFuente COLLATE Latin1_General_100_BIN2 AS TipoFuente
    INTO #Fuentes
    FROM AnalisisOpinionesClientes.dbo.Opiniones AS o
    JOIN AnalisisOpinionesClientes.dbo.FuenteDatos AS f ON f.IdFuente = o.IdFuente;

    IF NOT EXISTS (SELECT 1 FROM dbo.DimCliente WHERE ClienteKey = 0 AND IdClienteOrigen IS NULL)
        THROW 51302, N'Falta el miembro técnico de DimCliente.', 1;

    IF EXISTS
    (
        SELECT ClasificacionKey, Nombre
        FROM (VALUES (0,N'Pendiente'),(1,N'Positiva'),(2,N'Negativa'),(3,N'Neutra')) AS c(ClasificacionKey, Nombre)
        EXCEPT
        SELECT ClasificacionKey, Nombre FROM dbo.DimClasificacion
    )
        THROW 51303, N'El catálogo DimClasificacion está incompleto o difiere del modelo.', 1;

    IF EXISTS
    (
        SELECT 1 FROM #Productos AS o
        JOIN dbo.DimProducto AS d ON d.IdProductoOrigen = o.IdProductoOrigen
        WHERE CONVERT(varbinary(300), d.Nombre) <> CONVERT(varbinary(300), o.Nombre)
           OR CONVERT(varbinary(200), d.Categoria) <> CONVERT(varbinary(200), o.Categoria)
    )
        THROW 51304, N'DimProducto contiene atributos de origen diferentes para un código existente.', 1;

    INSERT dbo.DimProducto (IdProductoOrigen, Nombre, Categoria)
    SELECT o.IdProductoOrigen, o.Nombre, o.Categoria
    FROM #Productos AS o
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimProducto AS d WHERE d.IdProductoOrigen = o.IdProductoOrigen);

    DECLARE @insertadas int = @@ROWCOUNT;
    INSERT @resultado VALUES (N'DimProducto', (SELECT COUNT(*) FROM #Productos), @insertadas);

    IF EXISTS
    (
        SELECT 1 FROM #Clientes AS o
        JOIN dbo.DimCliente AS d ON d.IdClienteOrigen = o.IdClienteOrigen
        WHERE CONVERT(varbinary(240), d.Nombre) <> CONVERT(varbinary(240), o.Nombre)
    )
        THROW 51305, N'DimCliente contiene un nombre de origen diferente para un código existente.', 1;

    INSERT dbo.DimCliente (IdClienteOrigen, Nombre)
    SELECT o.IdClienteOrigen, o.Nombre
    FROM #Clientes AS o
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimCliente AS d WHERE d.IdClienteOrigen = o.IdClienteOrigen);

    SET @insertadas = @@ROWCOUNT;
    INSERT @resultado VALUES (N'DimCliente', (SELECT COUNT(*) FROM #Clientes) + 1, @insertadas);

    IF EXISTS
    (
        SELECT 1
        FROM #Fechas AS o
        JOIN dbo.DimFecha AS d ON d.Fecha = o.Fecha
        WHERE d.FechaKey <> CONVERT(int, CONVERT(char(8), o.Fecha, 112))
    )
        THROW 51306, N'DimFecha contiene una clave diferente para una fecha existente.', 1;

    INSERT dbo.DimFecha (FechaKey, Fecha)
    SELECT CONVERT(int, CONVERT(char(8), o.Fecha, 112)), o.Fecha
    FROM #Fechas AS o
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimFecha AS d WHERE d.Fecha = o.Fecha);

    SET @insertadas = @@ROWCOUNT;
    INSERT @resultado VALUES (N'DimFecha', (SELECT COUNT(*) FROM #Fechas), @insertadas);

    IF EXISTS
    (
        SELECT 1 FROM #Fuentes AS o
        JOIN dbo.DimFuente AS d ON d.IdFuenteOrigen = o.IdFuenteOrigen AND d.Canal = o.Canal
        WHERE CONVERT(varbinary(100), d.TipoFuente) <> CONVERT(varbinary(100), o.TipoFuente)
    )
        THROW 51307, N'DimFuente contiene un tipo de fuente diferente para un código y canal existentes.', 1;

    INSERT dbo.DimFuente (IdFuenteOrigen, Canal, TipoFuente)
    SELECT o.IdFuenteOrigen, o.Canal, o.TipoFuente
    FROM #Fuentes AS o
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.DimFuente AS d
        WHERE d.IdFuenteOrigen = o.IdFuenteOrigen AND d.Canal = o.Canal
    );

    SET @insertadas = @@ROWCOUNT;
    INSERT @resultado VALUES (N'DimFuente', (SELECT COUNT(*) FROM #Fuentes), @insertadas);
    INSERT @resultado VALUES (N'DimClasificacion', 4, 0);

    DROP TABLE #Productos, #Clientes, #Fechas, #Fuentes;

    COMMIT TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    SELECT Dimension, Esperadas, Insertadas, Esperadas - Insertadas AS Reutilizadas
    FROM @resultado
    ORDER BY Dimension;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
    THROW;
END CATCH;
