USE AnalisisOpinionesDW;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.vw_IndicadoresGenerales
AS
SELECT COUNT_BIG(*) AS Comentarios,
    COUNT_BIG(h.PuntajeSatisfaccion) AS OpinionesPuntuadas,
    COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END) AS OpinionesSatisfechas,
    AVG(CONVERT(decimal(19,4),h.PuntajeSatisfaccion)) AS PromedioSatisfaccion,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END)
        /NULLIF(COUNT_BIG(h.PuntajeSatisfaccion),0)) AS PorcentajeSatisfaccion,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END) AS Positivas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END) AS Negativas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END) AS Neutras,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=0 THEN 1 END) AS Pendientes,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajePositivas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNegativas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNeutras,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey<>0 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS CoberturaClasificacion
FROM dbo.HechoOpinion h;
GO

CREATE OR ALTER VIEW dbo.vw_IndicadoresProducto
AS
SELECT p.ProductoKey,p.IdProductoOrigen,p.Nombre,p.Categoria,
    SUM(CONVERT(bigint,h.PuntajeSatisfaccion)) AS SumaPuntajes,
    COUNT_BIG(*) AS Comentarios,
    COUNT_BIG(h.PuntajeSatisfaccion) AS OpinionesPuntuadas,
    COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END) AS OpinionesSatisfechas,
    AVG(CONVERT(decimal(19,4),h.PuntajeSatisfaccion)) AS PromedioSatisfaccion,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END)
        /NULLIF(COUNT_BIG(h.PuntajeSatisfaccion),0)) AS PorcentajeSatisfaccion,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END) AS Positivas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END) AS Negativas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END) AS Neutras,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=0 THEN 1 END) AS Pendientes,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajePositivas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNegativas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNeutras,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey<>0 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS CoberturaClasificacion
FROM dbo.HechoOpinion h
JOIN dbo.DimProducto p ON p.ProductoKey=h.ProductoKey
GROUP BY p.ProductoKey,p.IdProductoOrigen,p.Nombre,p.Categoria;
GO

CREATE OR ALTER VIEW dbo.vw_IndicadoresFuente
AS
SELECT f.FuenteKey,f.IdFuenteOrigen,f.Canal,f.TipoFuente,
    COUNT_BIG(*) AS Comentarios,
    COUNT_BIG(h.PuntajeSatisfaccion) AS OpinionesPuntuadas,
    COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END) AS OpinionesSatisfechas,
    AVG(CONVERT(decimal(19,4),h.PuntajeSatisfaccion)) AS PromedioSatisfaccion,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END)
        /NULLIF(COUNT_BIG(h.PuntajeSatisfaccion),0)) AS PorcentajeSatisfaccion,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END) AS Positivas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END) AS Negativas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END) AS Neutras,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=0 THEN 1 END) AS Pendientes,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajePositivas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNegativas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNeutras,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey<>0 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS CoberturaClasificacion
FROM dbo.HechoOpinion h
JOIN dbo.DimFuente f ON f.FuenteKey=h.FuenteKey
GROUP BY f.FuenteKey,f.IdFuenteOrigen,f.Canal,f.TipoFuente;
GO

CREATE OR ALTER VIEW dbo.vw_IndicadoresCanal
AS
SELECT f.Canal,
    COUNT_BIG(*) AS Comentarios,
    COUNT_BIG(h.PuntajeSatisfaccion) AS OpinionesPuntuadas,
    COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END) AS OpinionesSatisfechas,
    AVG(CONVERT(decimal(19,4),h.PuntajeSatisfaccion)) AS PromedioSatisfaccion,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END)
        /NULLIF(COUNT_BIG(h.PuntajeSatisfaccion),0)) AS PorcentajeSatisfaccion,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END) AS Positivas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END) AS Negativas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END) AS Neutras,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=0 THEN 1 END) AS Pendientes,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajePositivas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNegativas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNeutras,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey<>0 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS CoberturaClasificacion
FROM dbo.HechoOpinion h
JOIN dbo.DimFuente f ON f.FuenteKey=h.FuenteKey
GROUP BY f.Canal;
GO

CREATE OR ALTER VIEW dbo.vw_IndicadoresCliente
AS
SELECT c.ClienteKey,c.IdClienteOrigen,c.Nombre,
    CONVERT(bit,CASE WHEN c.ClienteKey=0 THEN 0 ELSE 1 END) AS ClienteIdentificado,
    COUNT_BIG(CASE WHEN h.CanalOrigen=N'Encuesta' THEN 1 END) AS Encuestas,
    COUNT_BIG(*) AS Comentarios,
    COUNT_BIG(h.PuntajeSatisfaccion) AS OpinionesPuntuadas,
    COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END) AS OpinionesSatisfechas,
    AVG(CONVERT(decimal(19,4),h.PuntajeSatisfaccion)) AS PromedioSatisfaccion,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END)
        /NULLIF(COUNT_BIG(h.PuntajeSatisfaccion),0)) AS PorcentajeSatisfaccion,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END) AS Positivas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END) AS Negativas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END) AS Neutras,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=0 THEN 1 END) AS Pendientes,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajePositivas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNegativas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNeutras,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey<>0 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS CoberturaClasificacion
FROM dbo.HechoOpinion h
JOIN dbo.DimCliente c ON c.ClienteKey=h.ClienteKey
GROUP BY c.ClienteKey,c.IdClienteOrigen,c.Nombre;
GO

CREATE OR ALTER VIEW dbo.vw_TendenciaMensual
AS
SELECT d.Anio,d.Mes,
    COUNT_BIG(*) AS Comentarios,
    COUNT_BIG(h.PuntajeSatisfaccion) AS OpinionesPuntuadas,
    COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END) AS OpinionesSatisfechas,
    AVG(CONVERT(decimal(19,4),h.PuntajeSatisfaccion)) AS PromedioSatisfaccion,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END)
        /NULLIF(COUNT_BIG(h.PuntajeSatisfaccion),0)) AS PorcentajeSatisfaccion,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END) AS Positivas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END) AS Negativas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END) AS Neutras,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=0 THEN 1 END) AS Pendientes,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajePositivas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNegativas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNeutras,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey<>0 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS CoberturaClasificacion
FROM dbo.HechoOpinion h
JOIN dbo.DimFecha d ON d.FechaKey=h.FechaKey
GROUP BY d.Anio,d.Mes;
GO

CREATE OR ALTER VIEW dbo.vw_TendenciaTrimestral
AS
SELECT d.Anio,d.Trimestre,
    COUNT_BIG(*) AS Comentarios,
    COUNT_BIG(h.PuntajeSatisfaccion) AS OpinionesPuntuadas,
    COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END) AS OpinionesSatisfechas,
    AVG(CONVERT(decimal(19,4),h.PuntajeSatisfaccion)) AS PromedioSatisfaccion,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END)
        /NULLIF(COUNT_BIG(h.PuntajeSatisfaccion),0)) AS PorcentajeSatisfaccion,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END) AS Positivas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END) AS Negativas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END) AS Neutras,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=0 THEN 1 END) AS Pendientes,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajePositivas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNegativas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNeutras,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey<>0 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS CoberturaClasificacion
FROM dbo.HechoOpinion h
JOIN dbo.DimFecha d ON d.FechaKey=h.FechaKey
GROUP BY d.Anio,d.Trimestre;
GO

CREATE OR ALTER VIEW dbo.vw_TendenciaProductoMensual
AS
SELECT p.ProductoKey,p.IdProductoOrigen,p.Nombre,d.Anio,d.Mes,
    COUNT_BIG(*) AS Comentarios,
    COUNT_BIG(h.PuntajeSatisfaccion) AS OpinionesPuntuadas,
    COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END) AS OpinionesSatisfechas,
    AVG(CONVERT(decimal(19,4),h.PuntajeSatisfaccion)) AS PromedioSatisfaccion,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.PuntajeSatisfaccion>=4 THEN 1 END)
        /NULLIF(COUNT_BIG(h.PuntajeSatisfaccion),0)) AS PorcentajeSatisfaccion,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END) AS Positivas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END) AS Negativas,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END) AS Neutras,
    COUNT_BIG(CASE WHEN h.ClasificacionKey=0 THEN 1 END) AS Pendientes,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=1 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajePositivas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=2 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNegativas,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey=3 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS PorcentajeNeutras,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(CASE WHEN h.ClasificacionKey<>0 THEN 1 END)
        /NULLIF(COUNT_BIG(*),0)) AS CoberturaClasificacion
FROM dbo.HechoOpinion h
JOIN dbo.DimProducto p ON p.ProductoKey=h.ProductoKey
JOIN dbo.DimFecha d ON d.FechaKey=h.FechaKey
GROUP BY p.ProductoKey,p.IdProductoOrigen,p.Nombre,d.Anio,d.Mes;
GO

CREATE OR ALTER VIEW dbo.vw_DistribucionClasificacion
AS
SELECT c.ClasificacionKey,c.Nombre,COUNT_BIG(h.OpinionKey) AS Comentarios,
    CONVERT(decimal(9,4),100.0*COUNT_BIG(h.OpinionKey)
        /NULLIF(SUM(COUNT_BIG(h.OpinionKey)) OVER (),0)) AS PorcentajeTotal
FROM dbo.DimClasificacion c
LEFT JOIN dbo.HechoOpinion h ON h.ClasificacionKey=c.ClasificacionKey
GROUP BY c.ClasificacionKey,c.Nombre;
GO
