USE AnalisisOpinionesDW;
GO
SET NOCOUNT ON;

IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0)<>6
    THROW 51220, N'El modelo debe contener seis tablas de usuario.', 1;

DECLARE @tablas table (Tabla sysname, Grupo sysname);
INSERT @tablas VALUES (N'DimProducto',N'FG_Dimensiones'),(N'DimCliente',N'FG_Dimensiones'),
    (N'DimFecha',N'FG_Dimensiones'),(N'DimFuente',N'FG_Dimensiones'),
    (N'DimClasificacion',N'FG_Dimensiones'),(N'HechoOpinion',N'FG_Hechos');

IF EXISTS
(
    SELECT 1 FROM @tablas e
    LEFT JOIN sys.tables t ON t.name=e.Tabla AND SCHEMA_NAME(t.schema_id)=N'dbo'
    LEFT JOIN sys.indexes i ON i.object_id=t.object_id AND i.index_id=1
    LEFT JOIN sys.filegroups g ON g.data_space_id=i.data_space_id
    WHERE t.object_id IS NULL OR g.name IS NULL OR g.name<>e.Grupo
)
    THROW 51221, N'Una tabla no tiene el indice agrupado en su filegroup esperado.', 1;

IF EXISTS
(
    SELECT 1 FROM @tablas e JOIN sys.tables t ON t.name=e.Tabla AND SCHEMA_NAME(t.schema_id)=N'dbo'
    JOIN sys.indexes i ON i.object_id=t.object_id
    LEFT JOIN sys.filegroups g ON g.data_space_id=i.data_space_id
    WHERE i.is_disabled=1 OR g.name IS NULL OR g.name<>e.Grupo
)
    THROW 51222, N'Hay indices deshabilitados o fuera del grupo de su tabla.', 1;

IF NOT EXISTS
(
    SELECT 1 FROM sys.tables t JOIN sys.filegroups g ON g.data_space_id=t.lob_data_space_id
    WHERE t.object_id=OBJECT_ID(N'dbo.HechoOpinion') AND g.name=N'FG_Hechos'
)
    THROW 51223, N'El texto largo de opiniones no esta asignado a FG_Hechos.', 1;

IF (SELECT COUNT(*) FROM sys.key_constraints WHERE type=N'PK')<>6
    OR (SELECT COUNT(*) FROM sys.foreign_keys)<>5
    OR EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1)
    OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)
    THROW 51224, N'Las claves o validaciones no estan completas, habilitadas y confiables.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name=N'FG_Dimensiones' AND is_default=1)
    OR (SELECT COUNT(*) FROM sys.filegroups)<>3
    OR (SELECT COUNT(*) FROM sys.database_files)<>4
    THROW 51225, N'La configuracion de almacenamiento no coincide con el modelo.', 1;

IF NOT EXISTS (SELECT 1 FROM dbo.DimCliente WHERE ClienteKey=0 AND IdClienteOrigen IS NULL AND Nombre IS NULL)
    OR (SELECT COUNT(*) FROM dbo.DimClasificacion)<>4
    THROW 51226, N'Faltan miembros tecnicos requeridos.', 1;

SELECT g.name AS Filegroup,g.is_default,g.is_read_only,f.name AS Archivo,f.type_desc,
    CONVERT(decimal(12,2),f.size/128.0) AS TamanoMB,
    CONVERT(decimal(12,2),f.growth/128.0) AS CrecimientoMB,f.is_percent_growth
FROM sys.database_files f LEFT JOIN sys.filegroups g ON g.data_space_id=f.data_space_id
ORDER BY f.file_id;

SELECT t.name AS Tabla,i.name AS Indice,i.type_desc,g.name AS Filegroup,
    i.is_unique,i.is_primary_key
FROM sys.tables t JOIN sys.indexes i ON i.object_id=t.object_id
JOIN sys.filegroups g ON g.data_space_id=i.data_space_id
WHERE t.is_ms_shipped=0 ORDER BY t.name,i.index_id;

SELECT name AS FK,OBJECT_NAME(parent_object_id) AS Tabla,OBJECT_NAME(referenced_object_id) AS Dimension,
    is_disabled,is_not_trusted FROM sys.foreign_keys ORDER BY name;

SELECT t.name AS Tabla,c.name AS Validacion,c.is_disabled,c.is_not_trusted
FROM sys.check_constraints c JOIN sys.tables t ON t.object_id=c.parent_object_id ORDER BY t.name,c.name;

SELECT N'DimProducto' AS Tabla,COUNT_BIG(*) AS Filas FROM dbo.DimProducto
UNION ALL SELECT N'DimCliente',COUNT_BIG(*) FROM dbo.DimCliente
UNION ALL SELECT N'DimFecha',COUNT_BIG(*) FROM dbo.DimFecha
UNION ALL SELECT N'DimFuente',COUNT_BIG(*) FROM dbo.DimFuente
UNION ALL SELECT N'DimClasificacion',COUNT_BIG(*) FROM dbo.DimClasificacion
UNION ALL SELECT N'HechoOpinion',COUNT_BIG(*) FROM dbo.HechoOpinion;

SELECT ClasificacionKey,Nombre FROM dbo.DimClasificacion ORDER BY ClasificacionKey;
SELECT ClienteKey,IdClienteOrigen,Nombre,Pais,FechaNacimiento,TipoCliente
FROM dbo.DimCliente WHERE ClienteKey=0;

PRINT N'OK: tablas, indices, LOB, seis PK, cinco FK confiables y miembros tecnicos verificados.';
GO
