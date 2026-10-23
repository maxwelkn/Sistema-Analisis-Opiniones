IF DB_ID(N'AnalisisOpinionesClientes') IS NULL
    EXEC(N'CREATE DATABASE AnalisisOpinionesClientes');
GO
USE AnalisisOpinionesClientes;
GO
SET XACT_ABORT ON;
BEGIN TRANSACTION;

IF OBJECT_ID(N'dbo.Clientes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Clientes
    (
    IdCliente int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Clientes PRIMARY KEY,
    Nombre nvarchar(120) NOT NULL,
    Email nvarchar(254) NULL,
    CONSTRAINT CK_Clientes_Nombre CHECK (LEN(LTRIM(RTRIM(Nombre))) > 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.Productos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Productos
    (
    IdProducto int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Productos PRIMARY KEY,
    Nombre nvarchar(150) NOT NULL,
    Categoria nvarchar(100) NOT NULL,
    CONSTRAINT CK_Productos_Nombre CHECK (LEN(LTRIM(RTRIM(Nombre))) > 0),
    CONSTRAINT CK_Productos_Categoria CHECK (LEN(LTRIM(RTRIM(Categoria))) > 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.FuenteDatos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FuenteDatos
    (
    IdFuente int IDENTITY(1,1) NOT NULL CONSTRAINT PK_FuenteDatos PRIMARY KEY,
    TipoFuente nvarchar(50) NOT NULL,
    FechaCarga datetime2(0) NOT NULL,
    CONSTRAINT CK_FuenteDatos_Tipo CHECK (LEN(LTRIM(RTRIM(TipoFuente))) > 0)
    );
END;
GO

IF OBJECT_ID(N'dbo.Opiniones', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Opiniones
    (
    IdOpinion bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_Opiniones PRIMARY KEY,
    IdCliente int NULL,
    IdProducto int NOT NULL,
    IdFuente int NOT NULL,
    Fecha datetime2(0) NOT NULL,
    Comentario nvarchar(max) NOT NULL,
    Clasificacion nvarchar(10) NULL,
    PuntajeSatisfaccion tinyint NULL,
    CONSTRAINT CK_Opiniones_Comentario CHECK (LEN(LTRIM(RTRIM(Comentario))) > 0),
    CONSTRAINT CK_Opiniones_Clasificacion CHECK (Clasificacion IN (N'Positiva', N'Negativa', N'Neutra')),
    CONSTRAINT CK_Opiniones_Puntaje CHECK (PuntajeSatisfaccion IS NULL OR PuntajeSatisfaccion BETWEEN 1 AND 5)
    );
END;
GO

IF COL_LENGTH(N'dbo.Clientes', N'IdExterno') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Clientes)
        THROW 51000, N'La tabla Clientes contiene datos sin correspondencia externa. Se requiere una migracion revisada.', 1;
    ALTER TABLE dbo.Clientes ADD IdExterno nvarchar(50) NOT NULL;
END;
GO

IF COL_LENGTH(N'dbo.Productos', N'IdExterno') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Productos)
        THROW 51000, N'La tabla Productos contiene datos sin correspondencia externa. Se requiere una migracion revisada.', 1;
    ALTER TABLE dbo.Productos ADD IdExterno nvarchar(50) NOT NULL;
END;
GO

IF COL_LENGTH(N'dbo.FuenteDatos', N'IdExterno') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.FuenteDatos)
        THROW 51000, N'La tabla FuenteDatos contiene datos sin correspondencia externa. Se requiere una migracion revisada.', 1;
    ALTER TABLE dbo.FuenteDatos ADD IdExterno nvarchar(100) NOT NULL;
END;
GO

IF COL_LENGTH(N'dbo.Opiniones', N'IdExterno') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Opiniones)
        THROW 51000, N'La tabla Opiniones contiene datos sin correspondencia externa. Se requiere una migracion revisada.', 1;
    ALTER TABLE dbo.Opiniones ADD IdExterno nvarchar(50) NOT NULL;
END;
GO

IF COL_LENGTH(N'dbo.Opiniones', N'Canal') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Opiniones)
        THROW 51000, N'La tabla Opiniones contiene datos sin correspondencia externa. Se requiere una migracion revisada.', 1;
    ALTER TABLE dbo.Opiniones ADD Canal nvarchar(20) NOT NULL;
END;
GO

IF COL_LENGTH(N'dbo.Opiniones', N'IdClienteOrigen') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Opiniones)
        THROW 51000, N'La tabla Opiniones contiene datos sin correspondencia externa. Se requiere una migracion revisada.', 1;
    ALTER TABLE dbo.Opiniones ADD IdClienteOrigen nvarchar(50) NULL;
END;
GO

IF COL_LENGTH(N'dbo.Opiniones', N'IdProductoOrigen') IS NULL
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.Opiniones)
        THROW 51000, N'La tabla Opiniones contiene datos sin correspondencia externa. Se requiere una migracion revisada.', 1;
    ALTER TABLE dbo.Opiniones ADD IdProductoOrigen nvarchar(50) NOT NULL;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Clientes') AND name=N'UX_Clientes_Origen')
    CREATE UNIQUE INDEX UX_Clientes_Origen ON dbo.Clientes (IdExterno);
GO

IF OBJECT_ID(N'dbo.CK_Clientes_IdExterno', N'C') IS NULL
    ALTER TABLE dbo.Clientes WITH CHECK ADD CONSTRAINT CK_Clientes_IdExterno CHECK (LEN(LTRIM(RTRIM(IdExterno))) > 0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Productos') AND name=N'UX_Productos_Origen')
    CREATE UNIQUE INDEX UX_Productos_Origen ON dbo.Productos (IdExterno);
GO

IF OBJECT_ID(N'dbo.CK_Productos_IdExterno', N'C') IS NULL
    ALTER TABLE dbo.Productos WITH CHECK ADD CONSTRAINT CK_Productos_IdExterno CHECK (LEN(LTRIM(RTRIM(IdExterno))) > 0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.FuenteDatos') AND name=N'UX_FuenteDatos_Origen')
    CREATE UNIQUE INDEX UX_FuenteDatos_Origen ON dbo.FuenteDatos (IdExterno);
GO

IF OBJECT_ID(N'dbo.CK_FuenteDatos_IdExterno', N'C') IS NULL
    ALTER TABLE dbo.FuenteDatos WITH CHECK ADD CONSTRAINT CK_FuenteDatos_IdExterno CHECK (LEN(LTRIM(RTRIM(IdExterno))) > 0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Opiniones') AND name=N'UX_Opiniones_Origen')
    CREATE UNIQUE INDEX UX_Opiniones_Origen ON dbo.Opiniones (Canal, IdExterno);
GO

IF OBJECT_ID(N'dbo.CK_Opiniones_IdExterno', N'C') IS NULL
    ALTER TABLE dbo.Opiniones WITH CHECK ADD CONSTRAINT CK_Opiniones_IdExterno CHECK (LEN(LTRIM(RTRIM(IdExterno))) > 0);
GO

ALTER TABLE dbo.Opiniones ALTER COLUMN Clasificacion nvarchar(10) NULL;
GO
IF OBJECT_ID(N'dbo.CK_Opiniones_Canal', N'C') IS NULL
    ALTER TABLE dbo.Opiniones WITH CHECK ADD CONSTRAINT CK_Opiniones_Canal CHECK (Canal IN (N'Web', N'Encuesta', N'RedSocial'));
IF OBJECT_ID(N'dbo.CK_Opiniones_ProductoOrigen', N'C') IS NULL
    ALTER TABLE dbo.Opiniones WITH CHECK ADD CONSTRAINT CK_Opiniones_ProductoOrigen CHECK (LEN(LTRIM(RTRIM(IdProductoOrigen))) > 0);
GO

IF OBJECT_ID(N'dbo.FK_Opiniones_Clientes', N'F') IS NULL
    ALTER TABLE dbo.Opiniones WITH CHECK ADD CONSTRAINT FK_Opiniones_Clientes FOREIGN KEY (IdCliente) REFERENCES dbo.Clientes(IdCliente);
ALTER TABLE dbo.Opiniones WITH CHECK CHECK CONSTRAINT FK_Opiniones_Clientes;
GO

IF OBJECT_ID(N'dbo.FK_Opiniones_Productos', N'F') IS NULL
    ALTER TABLE dbo.Opiniones WITH CHECK ADD CONSTRAINT FK_Opiniones_Productos FOREIGN KEY (IdProducto) REFERENCES dbo.Productos(IdProducto);
ALTER TABLE dbo.Opiniones WITH CHECK CHECK CONSTRAINT FK_Opiniones_Productos;
GO

IF OBJECT_ID(N'dbo.FK_Opiniones_FuenteDatos', N'F') IS NULL
    ALTER TABLE dbo.Opiniones WITH CHECK ADD CONSTRAINT FK_Opiniones_FuenteDatos FOREIGN KEY (IdFuente) REFERENCES dbo.FuenteDatos(IdFuente);
ALTER TABLE dbo.Opiniones WITH CHECK CHECK CONSTRAINT FK_Opiniones_FuenteDatos;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.Opiniones') AND name=N'IX_Opiniones_Producto_Fecha')
    CREATE INDEX IX_Opiniones_Producto_Fecha ON dbo.Opiniones(IdProducto, Fecha) INCLUDE (Clasificacion, PuntajeSatisfaccion);
COMMIT TRANSACTION;
GO
