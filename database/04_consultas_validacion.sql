USE AnalisisOpinionesClientes;
GO
EXEC dbo.usp_ObtenerConteos;

SELECT IdOpinion, IdCliente FROM dbo.Opiniones
WHERE IdCliente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Clientes c WHERE c.IdCliente=Opiniones.IdCliente);

SELECT IdOpinion, IdProducto FROM dbo.Opiniones
WHERE NOT EXISTS (SELECT 1 FROM dbo.Productos p WHERE p.IdProducto=Opiniones.IdProducto);

SELECT IdOpinion, IdFuente FROM dbo.Opiniones
WHERE NOT EXISTS (SELECT 1 FROM dbo.FuenteDatos f WHERE f.IdFuente=Opiniones.IdFuente);

SELECT Canal, IdExterno, COUNT_BIG(*) AS Repeticiones FROM dbo.Opiniones
GROUP BY Canal, IdExterno HAVING COUNT_BIG(*) > 1;

SELECT * FROM dbo.vw_ResumenCargaPorCanal;

SELECT TOP (20) * FROM dbo.vw_OpinionesDetalle ORDER BY IdOpinion;

SELECT o.IdOpinion, o.Canal, f.TipoFuente FROM dbo.Opiniones o
JOIN dbo.FuenteDatos f ON f.IdFuente=o.IdFuente
WHERE f.TipoFuente <> CASE o.Canal WHEN N'Web' THEN N'Web' WHEN N'Encuesta' THEN N'CSV' WHEN N'RedSocial' THEN N'Red Social' END;

SELECT name, is_disabled, is_not_trusted FROM sys.foreign_keys
WHERE parent_object_id=OBJECT_ID(N'dbo.Opiniones');
