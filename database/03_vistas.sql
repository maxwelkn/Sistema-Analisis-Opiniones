USE AnalisisOpinionesClientes;
GO
CREATE OR ALTER VIEW dbo.vw_OpinionesDetalle
AS
SELECT o.IdOpinion, o.IdExterno, o.Canal, o.IdClienteOrigen, o.IdProductoOrigen,
       o.IdCliente, c.Nombre AS NombreCliente, o.IdProducto, p.Nombre AS NombreProducto,
       o.IdFuente, f.IdExterno AS CodigoFuente, f.TipoFuente,
       o.Fecha, o.Comentario, o.Clasificacion, o.PuntajeSatisfaccion
FROM dbo.Opiniones o
LEFT JOIN dbo.Clientes c ON c.IdCliente = o.IdCliente
JOIN dbo.Productos p ON p.IdProducto = o.IdProducto
JOIN dbo.FuenteDatos f ON f.IdFuente = o.IdFuente;
GO
CREATE OR ALTER VIEW dbo.vw_ResumenCargaPorCanal
AS
SELECT Canal, COUNT_BIG(*) AS TotalOpiniones,
       SUM(CONVERT(bigint, CASE WHEN Clasificacion IS NULL THEN 1 ELSE 0 END)) AS PendientesClasificacion,
       SUM(CONVERT(bigint, CASE WHEN Clasificacion IS NOT NULL THEN 1 ELSE 0 END)) AS Clasificadas
FROM dbo.Opiniones
GROUP BY Canal;
GO
CREATE OR ALTER VIEW dbo.vw_CalidadReferencial
AS
SELECT o.IdOpinion,
       CASE WHEN o.IdCliente IS NOT NULL AND c.IdCliente IS NULL THEN 1 ELSE 0 END AS ClienteHuerfano,
       CASE WHEN p.IdProducto IS NULL THEN 1 ELSE 0 END AS ProductoHuerfano,
       CASE WHEN f.IdFuente IS NULL THEN 1 ELSE 0 END AS FuenteHuerfana
FROM dbo.Opiniones o
LEFT JOIN dbo.Clientes c ON c.IdCliente=o.IdCliente
LEFT JOIN dbo.Productos p ON p.IdProducto=o.IdProducto
LEFT JOIN dbo.FuenteDatos f ON f.IdFuente=o.IdFuente;
GO
