USE AnalisisOpinionesDW;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

IF @@TRANCOUNT<>0
    THROW 51209, N'Ejecute el script fuera de una transaccion existente.', 1;

DECLARE @identityHabilitada bit=0;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name=N'FG_Dimensiones' AND is_default=1 AND is_read_only=0)
        OR NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name=N'FG_Hechos' AND is_read_only=0)
        THROW 51210, N'Ejecute primero 01_crear_base_analitica.sql y compruebe los filegroups.', 1;

    DECLARE @firmaGuardada varchar(64) = CONVERT(varchar(64),
        (SELECT value FROM sys.extended_properties WHERE class=0 AND name=N'ETL_ModeloAnalitico_v1'));
    DECLARE @nuevo bit = CASE WHEN NOT EXISTS (SELECT 1 FROM sys.tables WHERE is_ms_shipped=0) THEN 1 ELSE 0 END;
    IF @nuevo=0 AND @firmaGuardada IS NULL
        THROW 51211, N'Hay tablas sin contrato de esquema v1. Se requiere una migracion revisada.', 1;
    IF @nuevo=1 AND @firmaGuardada IS NOT NULL
        THROW 51212, N'Faltan las tablas de un esquema ya registrado. No se reconstruiran automaticamente.', 1;

    IF @nuevo=1
    BEGIN
        CREATE TABLE dbo.DimProducto
        (
            ProductoKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProducto PRIMARY KEY CLUSTERED,
            IdProductoOrigen nvarchar(50) COLLATE Latin1_General_100_BIN2 NOT NULL,
            Nombre nvarchar(150) NOT NULL,
            Categoria nvarchar(100) NOT NULL,
            CONSTRAINT UQ_DimProducto_Origen UNIQUE (IdProductoOrigen),
            CONSTRAINT CK_DimProducto_Textos CHECK
                (LEN(LTRIM(RTRIM(IdProductoOrigen)))>0 AND LEN(LTRIM(RTRIM(Nombre)))>0 AND LEN(LTRIM(RTRIM(Categoria)))>0)
        ) ON FG_Dimensiones;

        CREATE TABLE dbo.DimCliente
        (
            ClienteKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCliente PRIMARY KEY CLUSTERED,
            IdClienteOrigen nvarchar(50) COLLATE Latin1_General_100_BIN2 NULL,
            Nombre nvarchar(120) NULL,
            Pais nvarchar(100) NULL,
            FechaNacimiento date NULL,
            TipoCliente nvarchar(50) NULL,
            CONSTRAINT CK_DimCliente_Identidad CHECK
            (
                (ClienteKey=0 AND IdClienteOrigen IS NULL AND Nombre IS NULL AND Pais IS NULL AND FechaNacimiento IS NULL AND TipoCliente IS NULL)
                OR (ClienteKey>0 AND IdClienteOrigen IS NOT NULL AND Nombre IS NOT NULL
                    AND LEN(LTRIM(RTRIM(IdClienteOrigen)))>0 AND LEN(LTRIM(RTRIM(Nombre)))>0)
            ),
            CONSTRAINT CK_DimCliente_Segmentos CHECK
                ((Pais IS NULL OR LEN(LTRIM(RTRIM(Pais)))>0) AND (TipoCliente IS NULL OR LEN(LTRIM(RTRIM(TipoCliente)))>0))
        ) ON FG_Dimensiones;
        CREATE UNIQUE INDEX UX_DimCliente_Origen ON dbo.DimCliente(IdClienteOrigen)
            WHERE IdClienteOrigen IS NOT NULL ON FG_Dimensiones;

        CREATE TABLE dbo.DimFecha
        (
            FechaKey int NOT NULL CONSTRAINT PK_DimFecha PRIMARY KEY CLUSTERED,
            Fecha date NOT NULL CONSTRAINT UQ_DimFecha_Fecha UNIQUE,
            Anio AS CONVERT(smallint,DATEPART(year,Fecha)) PERSISTED,
            Trimestre AS CONVERT(tinyint,DATEPART(quarter,Fecha)) PERSISTED,
            Mes AS CONVERT(tinyint,DATEPART(month,Fecha)) PERSISTED,
            Dia AS CONVERT(tinyint,DATEPART(day,Fecha)) PERSISTED,
            CONSTRAINT CK_DimFecha_Clave CHECK
                (FechaKey=DATEPART(year,Fecha)*10000+DATEPART(month,Fecha)*100+DATEPART(day,Fecha))
        ) ON FG_Dimensiones;

        CREATE TABLE dbo.DimFuente
        (
            FuenteKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimFuente PRIMARY KEY CLUSTERED,
            IdFuenteOrigen nvarchar(100) COLLATE Latin1_General_100_BIN2 NOT NULL,
            Canal nvarchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
            TipoFuente nvarchar(50) COLLATE Latin1_General_100_BIN2 NOT NULL,
            CONSTRAINT UQ_DimFuente_Origen UNIQUE (Canal,IdFuenteOrigen),
            CONSTRAINT UQ_DimFuente_Canal UNIQUE (FuenteKey,Canal),
            CONSTRAINT CK_DimFuente_Origen CHECK (LEN(LTRIM(RTRIM(IdFuenteOrigen)))>0),
            CONSTRAINT CK_DimFuente_Canal CHECK
                ((Canal=N'Web' AND TipoFuente=N'Web') OR (Canal=N'Encuesta' AND TipoFuente=N'CSV')
                    OR (Canal=N'RedSocial' AND TipoFuente=N'Red Social'))
        ) ON FG_Dimensiones;

        CREATE TABLE dbo.DimClasificacion
        (
            ClasificacionKey tinyint NOT NULL CONSTRAINT PK_DimClasificacion PRIMARY KEY CLUSTERED,
            Nombre nvarchar(10) COLLATE Latin1_General_100_BIN2 NOT NULL CONSTRAINT UQ_DimClasificacion_Nombre UNIQUE,
            CONSTRAINT CK_DimClasificacion_Catalogo CHECK
                ((ClasificacionKey=0 AND Nombre=N'Pendiente') OR (ClasificacionKey=1 AND Nombre=N'Positiva')
                    OR (ClasificacionKey=2 AND Nombre=N'Negativa') OR (ClasificacionKey=3 AND Nombre=N'Neutra'))
        ) ON FG_Dimensiones;

        CREATE TABLE dbo.HechoOpinion
        (
            OpinionKey bigint IDENTITY(1,1) NOT NULL,
            IdOpinionOrigen nvarchar(50) COLLATE Latin1_General_100_BIN2 NOT NULL,
            CanalOrigen nvarchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
            ProductoKey int NOT NULL,
            ClienteKey int NOT NULL,
            FechaKey int NOT NULL,
            FuenteKey int NOT NULL,
            ClasificacionKey tinyint NOT NULL,
            FechaOpinion datetime2(0) NOT NULL,
            Comentario nvarchar(max) NOT NULL,
            PuntajeSatisfaccion tinyint NULL,
            CONSTRAINT PK_HechoOpinion PRIMARY KEY NONCLUSTERED (OpinionKey) ON FG_Hechos,
            CONSTRAINT UQ_HechoOpinion_Origen UNIQUE NONCLUSTERED (CanalOrigen,IdOpinionOrigen) ON FG_Hechos,
            CONSTRAINT FK_HechoOpinion_Producto FOREIGN KEY (ProductoKey) REFERENCES dbo.DimProducto(ProductoKey),
            CONSTRAINT FK_HechoOpinion_Cliente FOREIGN KEY (ClienteKey) REFERENCES dbo.DimCliente(ClienteKey),
            CONSTRAINT FK_HechoOpinion_Fecha FOREIGN KEY (FechaKey) REFERENCES dbo.DimFecha(FechaKey),
            CONSTRAINT FK_HechoOpinion_Fuente FOREIGN KEY (FuenteKey,CanalOrigen) REFERENCES dbo.DimFuente(FuenteKey,Canal),
            CONSTRAINT FK_HechoOpinion_Clasificacion FOREIGN KEY (ClasificacionKey) REFERENCES dbo.DimClasificacion(ClasificacionKey),
            CONSTRAINT CK_HechoOpinion_Origen CHECK (LEN(LTRIM(RTRIM(IdOpinionOrigen)))>0),
            CONSTRAINT CK_HechoOpinion_Comentario CHECK (LEN(LTRIM(RTRIM(Comentario)))>0),
            CONSTRAINT CK_HechoOpinion_Puntaje CHECK (PuntajeSatisfaccion IS NULL OR PuntajeSatisfaccion BETWEEN 1 AND 5),
            CONSTRAINT CK_HechoOpinion_Fecha CHECK
                (FechaKey=DATEPART(year,FechaOpinion)*10000+DATEPART(month,FechaOpinion)*100+DATEPART(day,FechaOpinion))
        ) ON FG_Hechos TEXTIMAGE_ON FG_Hechos;
        CREATE UNIQUE CLUSTERED INDEX CX_HechoOpinion_Fecha ON dbo.HechoOpinion(FechaKey,OpinionKey) ON FG_Hechos;
        CREATE INDEX IX_HechoOpinion_Producto ON dbo.HechoOpinion(ProductoKey,FechaKey)
            INCLUDE (ClasificacionKey,PuntajeSatisfaccion) ON FG_Hechos;

        SET IDENTITY_INSERT dbo.DimCliente ON;
        SET @identityHabilitada=1;
        INSERT dbo.DimCliente(ClienteKey,IdClienteOrigen,Nombre,Pais,FechaNacimiento,TipoCliente)
            VALUES (0,NULL,NULL,NULL,NULL,NULL);
        SET IDENTITY_INSERT dbo.DimCliente OFF;
        SET @identityHabilitada=0;
        INSERT dbo.DimClasificacion(ClasificacionKey,Nombre)
            VALUES (0,N'Pendiente'),(1,N'Positiva'),(2,N'Negativa'),(3,N'Neutra');
    END;

    DECLARE @estructura nvarchar(max) =
    (
        SELECT s.name AS Esquema,t.name AS Tabla,ds.name AS GrupoLOB,
            JSON_QUERY((SELECT c.name,c.column_id,ty.name AS Tipo,c.max_length,c.precision,c.scale,
                    c.is_nullable,c.is_identity,c.collation_name,cc.definition AS Calculo,cc.is_persisted,
                    CONVERT(nvarchar(40),ic.seed_value) AS Semilla,CONVERT(nvarchar(40),ic.increment_value) AS Incremento,
                    dc.definition AS ValorPredeterminado
                FROM sys.columns c JOIN sys.types ty ON c.user_type_id=ty.user_type_id
                LEFT JOIN sys.computed_columns cc ON cc.object_id=c.object_id AND cc.column_id=c.column_id
                LEFT JOIN sys.identity_columns ic ON ic.object_id=c.object_id AND ic.column_id=c.column_id
                LEFT JOIN sys.default_constraints dc ON dc.object_id=c.default_object_id
                WHERE c.object_id=t.object_id ORDER BY c.column_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS Columnas,
            JSON_QUERY((SELECT i.name,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,
                    i.filter_definition,g.name AS Grupo,
                    JSON_QUERY((SELECT c.name,k.key_ordinal,k.is_descending_key,k.is_included_column
                        FROM sys.index_columns k JOIN sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id
                        WHERE k.object_id=i.object_id AND k.index_id=i.index_id
                        ORDER BY k.index_column_id FOR JSON PATH)) AS Columnas
                FROM sys.indexes i LEFT JOIN sys.data_spaces g ON g.data_space_id=i.data_space_id
                WHERE i.object_id=t.object_id ORDER BY i.name FOR JSON PATH,INCLUDE_NULL_VALUES)) AS Indices,
            JSON_QUERY((SELECT name,definition,is_disabled,is_not_trusted FROM sys.check_constraints
                WHERE parent_object_id=t.object_id ORDER BY name FOR JSON PATH)) AS Validaciones,
            JSON_QUERY((SELECT f.name,f.is_disabled,f.is_not_trusted,f.delete_referential_action,f.update_referential_action,
                    OBJECT_SCHEMA_NAME(f.referenced_object_id) AS EsquemaDestino,OBJECT_NAME(f.referenced_object_id) AS TablaDestino,
                    JSON_QUERY((SELECT COL_NAME(k.parent_object_id,k.parent_column_id) AS Columna,
                            COL_NAME(k.referenced_object_id,k.referenced_column_id) AS Referencia
                        FROM sys.foreign_key_columns k WHERE k.constraint_object_id=f.object_id
                        ORDER BY k.constraint_column_id FOR JSON PATH)) AS Columnas
                FROM sys.foreign_keys f WHERE f.parent_object_id=t.object_id ORDER BY f.name FOR JSON PATH)) AS Relaciones
        FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
        LEFT JOIN sys.data_spaces ds ON ds.data_space_id=t.lob_data_space_id
        WHERE t.is_ms_shipped=0 ORDER BY s.name,t.name FOR JSON PATH,INCLUDE_NULL_VALUES
    );
    DECLARE @firmaActual varchar(64) = CONVERT(varchar(64),HASHBYTES('SHA2_256',@estructura),2);
    IF @nuevo=0 AND @firmaActual<>@firmaGuardada
        THROW 51213, N'El esquema difiere de la version v1 registrada. No se reparara automaticamente.', 1;
    IF @nuevo=1
        EXEC sys.sp_addextendedproperty @name=N'ETL_ModeloAnalitico_v1',@value=@firmaActual;

    IF NOT EXISTS (SELECT 1 FROM dbo.DimCliente WHERE ClienteKey=0 AND IdClienteOrigen IS NULL AND Nombre IS NULL)
        OR (SELECT COUNT(*) FROM dbo.DimClasificacion)<>4
        THROW 51214, N'Faltan miembros tecnicos del modelo. Se requiere revision sin reinicializar datos.', 1;
    COMMIT TRANSACTION;
    PRINT N'OK: esquema estrella v1 verificado; no se cargaron opiniones ni catalogos de origen.';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @identityHabilitada=1 AND OBJECT_ID(N'dbo.DimCliente',N'U') IS NOT NULL
        SET IDENTITY_INSERT dbo.DimCliente OFF;
    THROW;
END CATCH;
GO
