USE master;
GO
SET NOCOUNT ON;

IF DB_ID(N'AnalisisOpinionesDW') IS NULL
BEGIN
    DECLARE @datos nvarchar(512) = CONVERT(nvarchar(512), SERVERPROPERTY('InstanceDefaultDataPath'));
    DECLARE @log nvarchar(512) = CONVERT(nvarchar(512), SERVERPROPERTY('InstanceDefaultLogPath'));
    IF NULLIF(@datos, N'') IS NULL OR NULLIF(@log, N'') IS NULL
        THROW 51200, N'No se pudieron resolver las rutas de datos y log de la instancia.', 1;

    DECLARE @sql nvarchar(max) = N'CREATE DATABASE AnalisisOpinionesDW ON PRIMARY
    (NAME=N''AnalisisOpinionesDW_Primary'', FILENAME=N''' + REPLACE(@datos + N'AnalisisOpinionesDW.mdf', N'''', N'''''') + N''', SIZE=64MB, FILEGROWTH=64MB),
    FILEGROUP FG_Dimensiones DEFAULT
    (NAME=N''AnalisisOpinionesDW_Dimensiones'', FILENAME=N''' + REPLACE(@datos + N'AnalisisOpinionesDW_Dimensiones.ndf', N'''', N'''''') + N''', SIZE=64MB, FILEGROWTH=64MB),
    FILEGROUP FG_Hechos
    (NAME=N''AnalisisOpinionesDW_Hechos'', FILENAME=N''' + REPLACE(@datos + N'AnalisisOpinionesDW_Hechos.ndf', N'''', N'''''') + N''', SIZE=64MB, FILEGROWTH=64MB)
    LOG ON
    (NAME=N''AnalisisOpinionesDW_Log'', FILENAME=N''' + REPLACE(@log + N'AnalisisOpinionesDW.ldf', N'''', N'''''') + N''', SIZE=64MB, FILEGROWTH=64MB);';
    EXEC sys.sp_executesql @sql;
    PRINT N'Base analitica creada. No se modifico la base transaccional.';
END;
GO
USE AnalisisOpinionesDW;
GO
SET NOCOUNT ON;

IF DATABASEPROPERTYEX(DB_NAME(), 'Updateability') <> N'READ_WRITE'
    THROW 51201, N'La base analitica no esta disponible para escritura.', 1;

IF (SELECT COUNT(*) FROM sys.filegroups) <> 3
    OR NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name=N'PRIMARY' AND is_read_only=0)
    OR NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name=N'FG_Dimensiones' AND is_default=1 AND is_read_only=0)
    OR NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name=N'FG_Hechos' AND is_read_only=0)
    THROW 51202, N'Los filegroups existentes no coinciden con el diseno. Se requiere revision, sin cambios automaticos.', 1;

DECLARE @archivos table (Nombre sysname, Tipo tinyint, Grupo sysname NULL);
INSERT @archivos VALUES
    (N'AnalisisOpinionesDW_Primary', 0, N'PRIMARY'),
    (N'AnalisisOpinionesDW_Dimensiones', 0, N'FG_Dimensiones'),
    (N'AnalisisOpinionesDW_Hechos', 0, N'FG_Hechos'),
    (N'AnalisisOpinionesDW_Log', 1, NULL);

IF (SELECT COUNT(*) FROM sys.database_files) <> 4 OR EXISTS
(
    SELECT 1
    FROM @archivos a
    LEFT JOIN sys.database_files f ON f.name=a.Nombre
    LEFT JOIN sys.filegroups g ON g.data_space_id=f.data_space_id
    WHERE f.file_id IS NULL OR f.type<>a.Tipo OR ISNULL(g.name,N'')<>ISNULL(a.Grupo,N'')
        OR f.size<8192 OR f.growth<>8192 OR f.is_percent_growth<>0 OR f.state<>0
)
    THROW 51203, N'Los archivos existentes no coinciden con el diseno. No se alteraron sus rutas, tamanos ni crecimiento.', 1;

PRINT N'OK: tres filegroups, dimensiones predeterminado, cuatro archivos y crecimiento fijo de 64 MB.';
GO
