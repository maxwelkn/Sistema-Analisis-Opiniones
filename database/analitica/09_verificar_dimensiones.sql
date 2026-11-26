USE AnalisisOpinionesDW;
SET NOCOUNT ON;

DECLARE @verificacion TABLE
(
    Dimension sysname PRIMARY KEY,
    TotalDW bigint NOT NULL,
    FaltantesODiferentes bigint NOT NULL
);

INSERT @verificacion
SELECT N'DimProducto', (SELECT COUNT_BIG(*) FROM dbo.DimProducto), COUNT_BIG(*)
FROM
(
    SELECT IdExterno COLLATE Latin1_General_100_BIN2 AS Codigo,
           CONVERT(varbinary(300), Nombre) AS Nombre, CONVERT(varbinary(200), Categoria) AS Categoria
    FROM AnalisisOpinionesClientes.dbo.Productos
    EXCEPT
    SELECT IdProductoOrigen, CONVERT(varbinary(300), Nombre), CONVERT(varbinary(200), Categoria)
    FROM dbo.DimProducto
) AS diferencias;

INSERT @verificacion
SELECT N'DimCliente', (SELECT COUNT_BIG(*) FROM dbo.DimCliente), COUNT_BIG(*) +
    CASE WHEN EXISTS (SELECT 1 FROM dbo.DimCliente WHERE ClienteKey = 0 AND IdClienteOrigen IS NULL) THEN 0 ELSE 1 END
FROM
(
    SELECT IdExterno COLLATE Latin1_General_100_BIN2 AS Codigo, CONVERT(varbinary(240), Nombre) AS Nombre
    FROM AnalisisOpinionesClientes.dbo.Clientes
    EXCEPT
    SELECT IdClienteOrigen, CONVERT(varbinary(240), Nombre) FROM dbo.DimCliente
) AS diferencias;

INSERT @verificacion
SELECT N'DimFecha', (SELECT COUNT_BIG(*) FROM dbo.DimFecha), COUNT_BIG(*)
FROM
(
    SELECT CONVERT(int, CONVERT(char(8), Fecha, 112)) AS FechaKey, CONVERT(date, Fecha) AS Fecha
    FROM AnalisisOpinionesClientes.dbo.Opiniones
    EXCEPT
    SELECT FechaKey, Fecha FROM dbo.DimFecha
) AS diferencias;

INSERT @verificacion
SELECT N'DimFuente', (SELECT COUNT_BIG(*) FROM dbo.DimFuente), COUNT_BIG(*)
FROM
(
    SELECT f.IdExterno COLLATE Latin1_General_100_BIN2 AS Codigo,
           o.Canal COLLATE Latin1_General_100_BIN2 AS Canal, CONVERT(varbinary(100), f.TipoFuente) AS TipoFuente
    FROM AnalisisOpinionesClientes.dbo.Opiniones AS o
    LEFT JOIN AnalisisOpinionesClientes.dbo.FuenteDatos AS f ON f.IdFuente = o.IdFuente
    EXCEPT
    SELECT IdFuenteOrigen, Canal, CONVERT(varbinary(100), TipoFuente)
    FROM dbo.DimFuente
) AS diferencias;

INSERT @verificacion
SELECT N'DimClasificacion', (SELECT COUNT_BIG(*) FROM dbo.DimClasificacion), COUNT_BIG(*)
FROM
(
    SELECT ClasificacionKey, Nombre
    FROM (VALUES (0,N'Pendiente'),(1,N'Positiva'),(2,N'Negativa'),(3,N'Neutra')) AS c(ClasificacionKey, Nombre)
    EXCEPT
    SELECT ClasificacionKey, Nombre FROM dbo.DimClasificacion
) AS diferencias;

SELECT Dimension, TotalDW, FaltantesODiferentes
FROM @verificacion
ORDER BY Dimension;

SELECT COUNT_BIG(*) AS TotalHechos FROM dbo.HechoOpinion;

SELECT TOP (5) ProductoKey, IdProductoOrigen, Categoria
FROM dbo.DimProducto ORDER BY IdProductoOrigen;

SELECT TOP (5) ClienteKey, COALESCE(IdClienteOrigen, N'(técnico)') AS IdClienteOrigen
FROM dbo.DimCliente ORDER BY ClienteKey;

SELECT MIN(Fecha) AS Desde, MAX(Fecha) AS Hasta FROM dbo.DimFecha;

SELECT TOP (5) FechaKey, Fecha, Anio, Trimestre, Mes, Dia
FROM dbo.DimFecha ORDER BY Fecha;

SELECT FuenteKey, IdFuenteOrigen, Canal, TipoFuente
FROM dbo.DimFuente ORDER BY Canal, IdFuenteOrigen;

SELECT ClasificacionKey, Nombre
FROM dbo.DimClasificacion ORDER BY ClasificacionKey;

IF EXISTS (SELECT 1 FROM @verificacion WHERE FaltantesODiferentes <> 0)
    THROW 51308, N'Hay miembros faltantes o diferentes respecto a los datos esperados.', 1;
