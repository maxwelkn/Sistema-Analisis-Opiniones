USE AnalisisOpinionesDW;
GO
SET NOCOUNT ON;

PRINT N'Consultas de opiniones almacenadas. No cuentan filas rechazadas ni ejecuciones ETL.';
PRINT N'Q01 y Q02: total aceptado y satisfaccion general; sin puntajes el promedio es NULL.';
SELECT Comentarios,OpinionesPuntuadas,PromedioSatisfaccion,PorcentajeSatisfaccion
FROM dbo.vw_IndicadoresGenerales;

PRINT N'Q03: comentarios por fuente de origen y canal.';
SELECT FuenteKey,IdFuenteOrigen,Canal,TipoFuente,Comentarios,OpinionesPuntuadas
FROM dbo.vw_IndicadoresFuente ORDER BY Canal,IdFuenteOrigen;

PRINT N'Q04, Q16 y Q18: clasificaciones, pendientes y porcentaje sobre todas las opiniones.';
SELECT ClasificacionKey,Nombre,Comentarios,PorcentajeTotal
FROM dbo.vw_DistribucionClasificacion ORDER BY ClasificacionKey;
SELECT Comentarios,Positivas,PorcentajePositivas,Pendientes,CoberturaClasificacion
FROM dbo.vw_IndicadoresGenerales;

PRINT N'Q05: productos con mas comentarios; incluye todos los empates.';
SELECT TOP (1) WITH TIES ProductoKey,IdProductoOrigen,Nombre,Comentarios
FROM dbo.vw_IndicadoresProducto ORDER BY Comentarios DESC;

PRINT N'Q06: productos con mejor promedio; solo productos puntuados, con cantidad de respaldo.';
SELECT p.ProductoKey,p.IdProductoOrigen,p.Nombre,p.PromedioSatisfaccion,p.OpinionesPuntuadas
FROM dbo.vw_IndicadoresProducto p
WHERE p.OpinionesPuntuadas>0 AND NOT EXISTS
(
    SELECT 1 FROM dbo.vw_IndicadoresProducto mejor WHERE mejor.OpinionesPuntuadas>0
        AND CONVERT(decimal(38,0),mejor.SumaPuntajes)*p.OpinionesPuntuadas
            >CONVERT(decimal(38,0),p.SumaPuntajes)*mejor.OpinionesPuntuadas
)
ORDER BY p.ProductoKey;

PRINT N'Q07: productos con mas opiniones negativas; sin negativas no hay ganador.';
SELECT TOP (1) WITH TIES ProductoKey,IdProductoOrigen,Nombre,Negativas,Comentarios,CoberturaClasificacion
FROM dbo.vw_IndicadoresProducto WHERE Negativas>0 ORDER BY Negativas DESC;

PRINT N'Q08: satisfaccion por producto y mes. Periodo anterior significa periodo observado, sin rellenar huecos.';
SELECT ProductoKey,IdProductoOrigen,Nombre,Anio,Mes,Comentarios,OpinionesPuntuadas,PromedioSatisfaccion,
    LAG(Anio) OVER (PARTITION BY ProductoKey ORDER BY Anio,Mes) AS AnioObservadoAnterior,
    LAG(Mes) OVER (PARTITION BY ProductoKey ORDER BY Anio,Mes) AS MesObservadoAnterior,
    PromedioSatisfaccion-LAG(PromedioSatisfaccion) OVER (PARTITION BY ProductoKey ORDER BY Anio,Mes) AS CambioPromedio
FROM dbo.vw_TendenciaProductoMensual ORDER BY ProductoKey,Anio,Mes;

PRINT N'Q09: porcentaje de satisfaccion por producto = puntajes 4 o 5 / opiniones puntuadas * 100.';
SELECT ProductoKey,IdProductoOrigen,Nombre,Comentarios,OpinionesPuntuadas,OpinionesSatisfechas,PorcentajeSatisfaccion
FROM dbo.vw_IndicadoresProducto ORDER BY ProductoKey;

PRINT N'Q10: clientes identificados con mas comentarios y con mas encuestas; desconocidos por separado.';
SELECT TOP (1) WITH TIES ClienteKey,IdClienteOrigen,Nombre,Comentarios,Encuestas
FROM dbo.vw_IndicadoresCliente WHERE ClienteIdentificado=1 ORDER BY Comentarios DESC;
SELECT TOP (1) WITH TIES ClienteKey,IdClienteOrigen,Nombre,Encuestas,Comentarios
FROM dbo.vw_IndicadoresCliente WHERE ClienteIdentificado=1 AND Encuestas>0 ORDER BY Encuestas DESC;
SELECT ClienteKey,Comentarios,Encuestas FROM dbo.vw_IndicadoresCliente WHERE ClienteIdentificado=0;

PRINT N'Q11 y Q12: pendientes de datos verificables de pais, nacimiento y tipo de cliente; sin resultados de segmentacion.';

PRINT N'Q13: percepcion mensual y trimestral; puntaje y sentimiento se muestran por separado.';
SELECT Anio,Mes,Comentarios,OpinionesPuntuadas,PromedioSatisfaccion,PorcentajeSatisfaccion,
    Positivas,Negativas,Neutras,Pendientes,CoberturaClasificacion
FROM dbo.vw_TendenciaMensual ORDER BY Anio,Mes;
SELECT Anio,Trimestre,Comentarios,OpinionesPuntuadas,PromedioSatisfaccion,PorcentajeSatisfaccion,
    Positivas,Negativas,Neutras,Pendientes,CoberturaClasificacion
FROM dbo.vw_TendenciaTrimestral ORDER BY Anio,Trimestre;

PRINT N'Q14: pendiente de eventos o campanas y de una asociacion verificable; no se infiere causalidad por fecha.';

PRINT N'Q15: cambio descriptivo entre periodos mensuales observados; un promedio ausente produce cambio NULL.';
SELECT Anio,Mes,Comentarios,OpinionesPuntuadas,PromedioSatisfaccion,
    LAG(Anio) OVER (ORDER BY Anio,Mes) AS AnioObservadoAnterior,
    LAG(Mes) OVER (ORDER BY Anio,Mes) AS MesObservadoAnterior,
    PromedioSatisfaccion-LAG(PromedioSatisfaccion) OVER (ORDER BY Anio,Mes) AS CambioPromedio
FROM dbo.vw_TendenciaMensual ORDER BY Anio,Mes;

PRINT N'Q17: analisis opcional de palabras clave no implementado; se conserva Comentario para una etapa posterior.';

PRINT N'Q19: canales con mas comentarios; incluye todos los empates.';
SELECT TOP (1) WITH TIES Canal,Comentarios FROM dbo.vw_IndicadoresCanal ORDER BY Comentarios DESC;

PRINT N'Q20: tono por canal, con pendientes y cobertura para interpretar la comparacion.';
SELECT Canal,Comentarios,Positivas,Negativas,Neutras,Pendientes,
    PorcentajePositivas,PorcentajeNegativas,PorcentajeNeutras,CoberturaClasificacion
FROM dbo.vw_IndicadoresCanal ORDER BY Canal;

PRINT N'Q21: canales con mayor proporcion negativa; sin negativas no hay ganador.';
SELECT c.Canal,c.Comentarios,c.Negativas,c.PorcentajeNegativas,c.CoberturaClasificacion
FROM dbo.vw_IndicadoresCanal c
WHERE c.Negativas>0 AND NOT EXISTS
(
    SELECT 1 FROM dbo.vw_IndicadoresCanal mayor
    WHERE CONVERT(decimal(38,0),mayor.Negativas)*c.Comentarios
        >CONVERT(decimal(38,0),c.Negativas)*mayor.Comentarios
)
ORDER BY c.Canal;
GO
