USE AnalisisOpinionesClientes;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarCliente
    @IdExterno nvarchar(50),
    @Nombre nvarchar(120),
    @Email nvarchar(254),
    @IdClienteResultado int OUTPUT,
    @Estado varchar(10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT = 0
        THROW 51010, N'La carga requiere una transaccion del llamador.', 1;
    SET @IdClienteResultado = NULL;
    SET @Estado = NULL;
    SELECT @IdClienteResultado = IdCliente
    FROM dbo.Clientes WITH (UPDLOCK, HOLDLOCK)
    WHERE IdExterno = @IdExterno;
    IF @IdClienteResultado IS NULL
    BEGIN
        INSERT INTO dbo.Clientes (IdExterno, Nombre, Email) VALUES (@IdExterno, @Nombre, @Email);
        SET @IdClienteResultado = CONVERT(int, SCOPE_IDENTITY());
        SET @Estado = 'Insertado';
    END
    ELSE IF EXISTS (SELECT @Nombre COLLATE Latin1_General_100_BIN2, @Email COLLATE Latin1_General_100_BIN2 EXCEPT SELECT Nombre COLLATE Latin1_General_100_BIN2, Email COLLATE Latin1_General_100_BIN2 FROM dbo.Clientes WHERE IdCliente = @IdClienteResultado)
        SET @Estado = 'Conflicto';
    ELSE
        SET @Estado = 'Omitido';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarProducto
    @IdExterno nvarchar(50),
    @Nombre nvarchar(150),
    @Categoria nvarchar(100),
    @IdProductoResultado int OUTPUT,
    @Estado varchar(10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT = 0
        THROW 51010, N'La carga requiere una transaccion del llamador.', 1;
    SET @IdProductoResultado = NULL;
    SET @Estado = NULL;
    SELECT @IdProductoResultado = IdProducto
    FROM dbo.Productos WITH (UPDLOCK, HOLDLOCK)
    WHERE IdExterno = @IdExterno;
    IF @IdProductoResultado IS NULL
    BEGIN
        INSERT INTO dbo.Productos (IdExterno, Nombre, Categoria) VALUES (@IdExterno, @Nombre, @Categoria);
        SET @IdProductoResultado = CONVERT(int, SCOPE_IDENTITY());
        SET @Estado = 'Insertado';
    END
    ELSE IF EXISTS (SELECT @Nombre COLLATE Latin1_General_100_BIN2, @Categoria COLLATE Latin1_General_100_BIN2 EXCEPT SELECT Nombre COLLATE Latin1_General_100_BIN2, Categoria COLLATE Latin1_General_100_BIN2 FROM dbo.Productos WHERE IdProducto = @IdProductoResultado)
        SET @Estado = 'Conflicto';
    ELSE
        SET @Estado = 'Omitido';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarFuente
    @IdExterno nvarchar(100),
    @TipoFuente nvarchar(50),
    @FechaCarga datetime2(0),
    @IdFuenteResultado int OUTPUT,
    @Estado varchar(10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT = 0
        THROW 51010, N'La carga requiere una transaccion del llamador.', 1;
    SET @IdFuenteResultado = NULL;
    SET @Estado = NULL;
    SELECT @IdFuenteResultado = IdFuente
    FROM dbo.FuenteDatos WITH (UPDLOCK, HOLDLOCK)
    WHERE IdExterno = @IdExterno;
    IF @IdFuenteResultado IS NULL
    BEGIN
        INSERT INTO dbo.FuenteDatos (IdExterno, TipoFuente, FechaCarga) VALUES (@IdExterno, @TipoFuente, @FechaCarga);
        SET @IdFuenteResultado = CONVERT(int, SCOPE_IDENTITY());
        SET @Estado = 'Insertado';
    END
    ELSE IF EXISTS (SELECT @TipoFuente COLLATE Latin1_General_100_BIN2, @FechaCarga EXCEPT SELECT TipoFuente COLLATE Latin1_General_100_BIN2, FechaCarga FROM dbo.FuenteDatos WHERE IdFuente = @IdFuenteResultado)
        SET @Estado = 'Conflicto';
    ELSE
        SET @Estado = 'Omitido';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CargarOpinion
    @IdExterno nvarchar(50),
    @Canal nvarchar(20),
    @IdCliente int,
    @IdProducto int,
    @IdFuente int,
    @Fecha datetime2(0),
    @Comentario nvarchar(max),
    @Clasificacion nvarchar(10),
    @PuntajeSatisfaccion tinyint,
    @IdClienteOrigen nvarchar(50),
    @IdProductoOrigen nvarchar(50),
    @IdOpinionResultado bigint OUTPUT,
    @Estado varchar(10) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @@TRANCOUNT = 0
        THROW 51010, N'La carga requiere una transaccion del llamador.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.FuenteDatos WHERE IdFuente = @IdFuente AND TipoFuente = CASE @Canal WHEN N'Web' THEN N'Web' WHEN N'Encuesta' THEN N'CSV' WHEN N'RedSocial' THEN N'Red Social' END)
        THROW 51011, N'La fuente no corresponde al canal de la opinion.', 1;
    SET @IdOpinionResultado = NULL;
    SET @Estado = NULL;
    SELECT @IdOpinionResultado = IdOpinion
    FROM dbo.Opiniones WITH (UPDLOCK, HOLDLOCK)
    WHERE IdExterno = @IdExterno AND Canal = @Canal;
    IF @IdOpinionResultado IS NULL
    BEGIN
        INSERT INTO dbo.Opiniones (IdExterno, Canal, IdCliente, IdProducto, IdFuente, Fecha, Comentario, Clasificacion, PuntajeSatisfaccion, IdClienteOrigen, IdProductoOrigen) VALUES (@IdExterno, @Canal, @IdCliente, @IdProducto, @IdFuente, @Fecha, @Comentario, @Clasificacion, @PuntajeSatisfaccion, @IdClienteOrigen, @IdProductoOrigen);
        SET @IdOpinionResultado = CONVERT(bigint, SCOPE_IDENTITY());
        SET @Estado = 'Insertado';
    END
    ELSE IF EXISTS (SELECT @Canal COLLATE Latin1_General_100_BIN2, @IdCliente, @IdProducto, @IdFuente, @Fecha, @Comentario COLLATE Latin1_General_100_BIN2, @Clasificacion COLLATE Latin1_General_100_BIN2, @PuntajeSatisfaccion, @IdClienteOrigen COLLATE Latin1_General_100_BIN2, @IdProductoOrigen COLLATE Latin1_General_100_BIN2 EXCEPT SELECT Canal COLLATE Latin1_General_100_BIN2, IdCliente, IdProducto, IdFuente, Fecha, Comentario COLLATE Latin1_General_100_BIN2, Clasificacion COLLATE Latin1_General_100_BIN2, PuntajeSatisfaccion, IdClienteOrigen COLLATE Latin1_General_100_BIN2, IdProductoOrigen COLLATE Latin1_General_100_BIN2 FROM dbo.Opiniones WHERE IdOpinion = @IdOpinionResultado)
        SET @Estado = 'Conflicto';
    ELSE
        SET @Estado = 'Omitido';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ObtenerConteos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT N'Clientes' AS Tabla, COUNT_BIG(*) AS Registros FROM dbo.Clientes
    UNION ALL SELECT N'Productos', COUNT_BIG(*) FROM dbo.Productos
    UNION ALL SELECT N'FuenteDatos', COUNT_BIG(*) FROM dbo.FuenteDatos
    UNION ALL SELECT N'Opiniones', COUNT_BIG(*) FROM dbo.Opiniones;
END;
GO
