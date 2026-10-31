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
    THROW 51240,N'Ejecute las pruebas fuera de una transaccion existente.',1;
IF EXISTS(SELECT 1 FROM dbo.HechoOpinion)
    THROW 51240,N'Estas pruebas necesitan una base sin opiniones. No se borraran datos existentes.',1;
IF EXISTS(SELECT 1 FROM dbo.DimProducto WHERE IdProductoOrigen IN(N'__CALC_A',N'__CALC_B',N'__CALC_C',N'__CALC_D',N'__PREC_E',N'__PREC_F'))
    OR EXISTS(SELECT 1 FROM dbo.DimCliente WHERE IdClienteOrigen IN(N'__CALC_X',N'__CALC_Y'))
    OR EXISTS(SELECT 1 FROM dbo.DimFuente WHERE IdFuenteOrigen IN(N'__CALC_W1',N'__CALC_W2',N'__CALC_E',N'__CALC_R',N'__CALC_SIN_USO'))
    OR EXISTS(SELECT 1 FROM dbo.DimFecha WHERE FechaKey IN(20250115,20250116,20250215,20260115))
    THROW 51240,N'Las claves o fechas reservadas de calculo ya existen. Revise un entorno de prueba vacio.',1;

DECLARE @resultados table(Id int IDENTITY,Prueba nvarchar(150));
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE Comentarios=0 AND OpinionesPuntuadas=0 AND OpinionesSatisfechas=0 AND Positivas=0 AND Negativas=0 AND Neutras=0 AND Pendientes=0))
        THROW 51241,N'General vacio: una fila con conteos cero',1;
    INSERT @resultados(Prueba) VALUES(N'General vacio: una fila con conteos cero');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE PromedioSatisfaccion IS NULL AND PorcentajeSatisfaccion IS NULL AND PorcentajePositivas IS NULL AND PorcentajeNegativas IS NULL AND PorcentajeNeutras IS NULL AND CoberturaClasificacion IS NULL))
        THROW 51241,N'General vacio: promedios y porcentajes NULL',1;
    INSERT @resultados(Prueba) VALUES(N'General vacio: promedios y porcentajes NULL');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_DistribucionClasificacion)=4 AND NOT EXISTS(SELECT 1 FROM dbo.vw_DistribucionClasificacion WHERE Comentarios<>0 OR PorcentajeTotal IS NOT NULL))
        THROW 51241,N'Distribucion vacia mantiene cuatro estados',1;
    INSERT @resultados(Prueba) VALUES(N'Distribucion vacia mantiene cuatro estados');

    IF NOT (NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto) AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresFuente) AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCanal) AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCliente) AND NOT EXISTS(SELECT 1 FROM dbo.vw_TendenciaMensual) AND NOT EXISTS(SELECT 1 FROM dbo.vw_TendenciaTrimestral) AND NOT EXISTS(SELECT 1 FROM dbo.vw_TendenciaProductoMensual))
        THROW 51241,N'Sin opiniones no hay grupos ni ganadores',1;
    INSERT @resultados(Prueba) VALUES(N'Sin opiniones no hay grupos ni ganadores');

    INSERT dbo.DimProducto(IdProductoOrigen,Nombre,Categoria) VALUES
        (N'__CALC_A',N'Producto temporal A',N'Prueba'),(N'__CALC_B',N'Producto temporal B',N'Prueba'),
        (N'__CALC_C',N'Producto temporal C',N'Prueba'),(N'__CALC_D',N'Producto sin opiniones',N'Prueba');
    DECLARE @a int=(SELECT ProductoKey FROM dbo.DimProducto WHERE IdProductoOrigen=N'__CALC_A');
    DECLARE @b int=(SELECT ProductoKey FROM dbo.DimProducto WHERE IdProductoOrigen=N'__CALC_B');
    DECLARE @c int=(SELECT ProductoKey FROM dbo.DimProducto WHERE IdProductoOrigen=N'__CALC_C');
    INSERT dbo.DimCliente(IdClienteOrigen,Nombre) VALUES(N'__CALC_X',N'Cliente temporal X'),(N'__CALC_Y',N'Cliente temporal Y');
    DECLARE @x int=(SELECT ClienteKey FROM dbo.DimCliente WHERE IdClienteOrigen=N'__CALC_X');
    DECLARE @y int=(SELECT ClienteKey FROM dbo.DimCliente WHERE IdClienteOrigen=N'__CALC_Y');
    INSERT dbo.DimFecha(FechaKey,Fecha) VALUES(20250115,'2025-01-15'),(20250116,'2025-01-16'),(20250215,'2025-02-15'),(20260115,'2026-01-15');
    INSERT dbo.DimFuente(IdFuenteOrigen,Canal,TipoFuente) VALUES
        (N'__CALC_W1',N'Web',N'Web'),(N'__CALC_W2',N'Web',N'Web'),(N'__CALC_E',N'Encuesta',N'CSV'),
        (N'__CALC_R',N'RedSocial',N'Red Social'),(N'__CALC_SIN_USO',N'Web',N'Web');
    DECLARE @w1 int=(SELECT FuenteKey FROM dbo.DimFuente WHERE IdFuenteOrigen=N'__CALC_W1');
    DECLARE @w2 int=(SELECT FuenteKey FROM dbo.DimFuente WHERE IdFuenteOrigen=N'__CALC_W2');
    DECLARE @e int=(SELECT FuenteKey FROM dbo.DimFuente WHERE IdFuenteOrigen=N'__CALC_E');
    DECLARE @r int=(SELECT FuenteKey FROM dbo.DimFuente WHERE IdFuenteOrigen=N'__CALC_R');
    INSERT dbo.HechoOpinion(IdOpinionOrigen,CanalOrigen,ProductoKey,ClienteKey,FechaKey,FuenteKey,ClasificacionKey,FechaOpinion,Comentario,PuntajeSatisfaccion)
    VALUES
        (N'__CALC_1',N'Web',@a,@x,20250115,@w1,1,'2025-01-15',N'Prueba calculo 1',5),
        (N'__CALC_2',N'Encuesta',@a,@y,20250116,@e,1,'2025-01-16',N'Prueba calculo 2',4),
        (N'__CALC_3',N'Web',@a,@x,20250215,@w1,2,'2025-02-15',N'Prueba calculo 3',1),
        (N'__CALC_4',N'RedSocial',@a,0,20260115,@r,0,'2026-01-15',N'Prueba calculo 4',NULL),
        (N'__CALC_5',N'Web',@b,@x,20250115,@w2,2,'2025-01-15',N'Prueba calculo 5',5),
        (N'__CALC_6',N'Encuesta',@b,@y,20250116,@e,3,'2025-01-16',N'Prueba calculo 6',4),
        (N'__CALC_7',N'Web',@b,@y,20250215,@w2,2,'2025-02-15',N'Prueba calculo 7',1),
        (N'__CALC_8',N'RedSocial',@b,0,20260115,@r,0,'2026-01-15',N'Prueba calculo 8',NULL),
        (N'__CALC_9',N'RedSocial',@c,0,20250115,@r,3,'2025-01-15',N'Prueba calculo 9',NULL),
        (N'__CALC_10',N'RedSocial',@c,0,20260115,@r,0,'2026-01-15',N'Prueba calculo 10',NULL);

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE Comentarios=10 AND OpinionesPuntuadas=6 AND OpinionesSatisfechas=4))
        THROW 51241,N'Total individual y denominador puntuado',1;
    INSERT @resultados(Prueba) VALUES(N'Total individual y denominador puntuado');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE PromedioSatisfaccion=CONVERT(decimal(38,6),3.333333)))
        THROW 51241,N'Promedio ignora NULL y conserva decimales',1;
    INSERT @resultados(Prueba) VALUES(N'Promedio ignora NULL y conserva decimales');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE PorcentajeSatisfaccion=66.6667))
        THROW 51241,N'Satisfaccion divide entre puntuados',1;
    INSERT @resultados(Prueba) VALUES(N'Satisfaccion divide entre puntuados');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE Positivas=2 AND Negativas=3 AND Neutras=2 AND Pendientes=3 AND CoberturaClasificacion=70))
        THROW 51241,N'Sentimientos y pendientes separados',1;
    INSERT @resultados(Prueba) VALUES(N'Sentimientos y pendientes separados');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE PorcentajePositivas=20 AND PorcentajeNegativas=30 AND PorcentajeNeutras=20))
        THROW 51241,N'Porcentajes usan todas las opiniones',1;
    INSERT @resultados(Prueba) VALUES(N'Porcentajes usan todas las opiniones');

    IF NOT ((SELECT SUM(Comentarios) FROM dbo.vw_DistribucionClasificacion)=10 AND (SELECT SUM(PorcentajeTotal) FROM dbo.vw_DistribucionClasificacion)=100)
        THROW 51241,N'Distribucion reconciliada con total',1;
    INSERT @resultados(Prueba) VALUES(N'Distribucion reconciliada con total');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_DistribucionClasificacion WHERE ClasificacionKey=0 AND Comentarios=3 AND PorcentajeTotal=30) AND EXISTS(SELECT 1 FROM dbo.vw_DistribucionClasificacion WHERE ClasificacionKey=3 AND Comentarios=2 AND PorcentajeTotal=20))
        THROW 51241,N'Pendientes no son neutras',1;
    INSERT @resultados(Prueba) VALUES(N'Pendientes no son neutras');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_IndicadoresProducto)=3 AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE IdProductoOrigen=N'__CALC_D'))
        THROW 51241,N'Solo productos con opiniones',1;
    INSERT @resultados(Prueba) VALUES(N'Solo productos con opiniones');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_IndicadoresProducto WHERE IdProductoOrigen IN(N'__CALC_A',N'__CALC_B') AND Comentarios=4 AND OpinionesPuntuadas=3 AND OpinionesSatisfechas=2 AND PorcentajeSatisfaccion=66.6667)=2)
        THROW 51241,N'Conteos por producto conservan el grano',1;
    INSERT @resultados(Prueba) VALUES(N'Conteos por producto conservan el grano');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE IdProductoOrigen=N'__CALC_C' AND Comentarios=2 AND OpinionesPuntuadas=0 AND PromedioSatisfaccion IS NULL AND PorcentajeSatisfaccion IS NULL))
        THROW 51241,N'Producto sin puntaje no obtiene cero',1;
    INSERT @resultados(Prueba) VALUES(N'Producto sin puntaje no obtiene cero');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE IdProductoOrigen=N'__CALC_A' AND Negativas=1) AND EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE IdProductoOrigen=N'__CALC_B' AND Negativas=2))
        THROW 51241,N'Mas negativas distingue productos',1;
    INSERT @resultados(Prueba) VALUES(N'Mas negativas distingue productos');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_IndicadoresProducto WHERE Comentarios=(SELECT MAX(Comentarios) FROM dbo.vw_IndicadoresProducto))=2)
        THROW 51241,N'Empate de productos por comentarios',1;
    INSERT @resultados(Prueba) VALUES(N'Empate de productos por comentarios');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_IndicadoresProducto WHERE OpinionesPuntuadas>0 AND PromedioSatisfaccion=(SELECT MAX(PromedioSatisfaccion) FROM dbo.vw_IndicadoresProducto))=2)
        THROW 51241,N'Empate de productos por promedio',1;
    INSERT @resultados(Prueba) VALUES(N'Empate de productos por promedio');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_IndicadoresFuente)=4 AND (SELECT COUNT(*) FROM dbo.vw_IndicadoresFuente WHERE Canal=N'Web' AND Comentarios=2)=2 AND (SELECT SUM(Comentarios) FROM dbo.vw_IndicadoresFuente)=10)
        THROW 51241,N'Fuentes no se colapsan al agrupar por canal',1;
    INSERT @resultados(Prueba) VALUES(N'Fuentes no se colapsan al agrupar por canal');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_IndicadoresCanal)=3 AND (SELECT SUM(Comentarios) FROM dbo.vw_IndicadoresCanal)=10)
        THROW 51241,N'Canales reconciliados con total',1;
    INSERT @resultados(Prueba) VALUES(N'Canales reconciliados con total');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCanal WHERE Canal=N'Web' AND Comentarios=4 AND Negativas=3 AND PorcentajeNegativas=75 AND PromedioSatisfaccion=3 AND PorcentajeSatisfaccion=50 AND CoberturaClasificacion=100))
        THROW 51241,N'Web: proporcion negativa y puntaje independientes',1;
    INSERT @resultados(Prueba) VALUES(N'Web: proporcion negativa y puntaje independientes');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCanal WHERE Canal=N'Encuesta' AND Comentarios=2 AND Positivas=1 AND Neutras=1 AND PorcentajeSatisfaccion=100 AND PromedioSatisfaccion=4))
        THROW 51241,N'Encuesta: puntajes satisfechos y tono distinto',1;
    INSERT @resultados(Prueba) VALUES(N'Encuesta: puntajes satisfechos y tono distinto');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCanal WHERE Canal=N'RedSocial' AND Comentarios=4 AND OpinionesPuntuadas=0 AND PromedioSatisfaccion IS NULL AND PorcentajeSatisfaccion IS NULL AND Pendientes=3 AND Neutras=1 AND CoberturaClasificacion=25))
        THROW 51241,N'Redes: sin puntajes y clasificacion incompleta',1;
    INSERT @resultados(Prueba) VALUES(N'Redes: sin puntajes y clasificacion incompleta');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_IndicadoresCanal WHERE Comentarios=(SELECT MAX(Comentarios) FROM dbo.vw_IndicadoresCanal))=2)
        THROW 51241,N'Empate de canales con mayor volumen',1;
    INSERT @resultados(Prueba) VALUES(N'Empate de canales con mayor volumen');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCliente WHERE ClienteIdentificado=0 AND ClienteKey=0 AND Nombre IS NULL AND Comentarios=4) AND (SELECT COUNT(*) FROM dbo.vw_IndicadoresCliente WHERE ClienteIdentificado=1 AND Comentarios=3)=2)
        THROW 51241,N'Cliente desconocido separado de personas',1;
    INSERT @resultados(Prueba) VALUES(N'Cliente desconocido separado de personas');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCliente WHERE IdClienteOrigen=N'__CALC_Y' AND Encuestas=2) AND EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCliente WHERE IdClienteOrigen=N'__CALC_X' AND Encuestas=0))
        THROW 51241,N'Encuestas por cliente identificado',1;
    INSERT @resultados(Prueba) VALUES(N'Encuestas por cliente identificado');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_IndicadoresCliente WHERE ClienteIdentificado=1 AND Comentarios=(SELECT MAX(Comentarios) FROM dbo.vw_IndicadoresCliente WHERE ClienteIdentificado=1))=2)
        THROW 51241,N'Empate de clientes excluye desconocidos',1;
    INSERT @resultados(Prueba) VALUES(N'Empate de clientes excluye desconocidos');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_TendenciaMensual)=3 AND EXISTS(SELECT 1 FROM dbo.vw_TendenciaMensual WHERE Anio=2025 AND Mes=1 AND Comentarios=5) AND EXISTS(SELECT 1 FROM dbo.vw_TendenciaMensual WHERE Anio=2026 AND Mes=1 AND Comentarios=3))
        THROW 51241,N'Meses de anios distintos permanecen separados',1;
    INSERT @resultados(Prueba) VALUES(N'Meses de anios distintos permanecen separados');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_TendenciaMensual WHERE Anio=2025 AND Mes=1 AND OpinionesPuntuadas=4 AND PromedioSatisfaccion=4.5 AND PorcentajeSatisfaccion=100 AND Positivas=2 AND Negativas=1 AND Neutras=2))
        THROW 51241,N'Enero: promedio ponderado por opiniones',1;
    INSERT @resultados(Prueba) VALUES(N'Enero: promedio ponderado por opiniones');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_TendenciaMensual WHERE Anio=2025 AND Mes=2 AND Comentarios=2 AND PromedioSatisfaccion=1 AND PorcentajeSatisfaccion=0 AND Negativas=2))
        THROW 51241,N'Febrero: deterioro descriptivo puntuado',1;
    INSERT @resultados(Prueba) VALUES(N'Febrero: deterioro descriptivo puntuado');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_TendenciaMensual WHERE Anio=2026 AND Mes=1 AND PromedioSatisfaccion IS NULL AND PorcentajeSatisfaccion IS NULL AND Pendientes=3 AND CoberturaClasificacion=0))
        THROW 51241,N'Periodo sin puntaje sigue sin promedio',1;
    INSERT @resultados(Prueba) VALUES(N'Periodo sin puntaje sigue sin promedio');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_TendenciaTrimestral)=2 AND EXISTS(SELECT 1 FROM dbo.vw_TendenciaTrimestral WHERE Anio=2025 AND Trimestre=1 AND Comentarios=7 AND OpinionesPuntuadas=6 AND PromedioSatisfaccion=3.333333) AND EXISTS(SELECT 1 FROM dbo.vw_TendenciaTrimestral WHERE Anio=2026 AND Trimestre=1 AND Comentarios=3))
        THROW 51241,N'Trimestres incluyen anio y agrupan hechos',1;
    INSERT @resultados(Prueba) VALUES(N'Trimestres incluyen anio y agrupan hechos');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_TendenciaProductoMensual)=8 AND EXISTS(SELECT 1 FROM dbo.vw_TendenciaProductoMensual WHERE IdProductoOrigen=N'__CALC_A' AND Anio=2025 AND Mes=1 AND Comentarios=2 AND PromedioSatisfaccion=4.5) AND EXISTS(SELECT 1 FROM dbo.vw_TendenciaProductoMensual WHERE IdProductoOrigen=N'__CALC_A' AND Anio=2026 AND Mes=1 AND Comentarios=1 AND PromedioSatisfaccion IS NULL))
        THROW 51241,N'Producto y mes no mezclan periodos',1;
    INSERT @resultados(Prueba) VALUES(N'Producto y mes no mezclan periodos');

    IF NOT (EXISTS(SELECT 1 FROM (SELECT Anio,Mes,PromedioSatisfaccion-LAG(PromedioSatisfaccion) OVER(ORDER BY Anio,Mes) AS Cambio FROM dbo.vw_TendenciaMensual) x WHERE Anio=2025 AND Mes=2 AND Cambio=-3.5) AND EXISTS(SELECT 1 FROM (SELECT Anio,Mes,PromedioSatisfaccion-LAG(PromedioSatisfaccion) OVER(ORDER BY Anio,Mes) AS Cambio FROM dbo.vw_TendenciaMensual) x WHERE Anio=2026 AND Mes=1 AND Cambio IS NULL))
        THROW 51241,N'Cambios mensuales respetan NULL y periodos observados',1;
    INSERT @resultados(Prueba) VALUES(N'Cambios mensuales respetan NULL y periodos observados');

    SAVE TRANSACTION AntesPrecision;
    DELETE FROM dbo.HechoOpinion;
    INSERT dbo.DimProducto(IdProductoOrigen,Nombre,Categoria) VALUES
        (N'__PREC_E',N'Producto temporal precision E',N'Prueba'),
        (N'__PREC_F',N'Producto temporal precision F',N'Prueba');
    DECLARE @pe int=(SELECT ProductoKey FROM dbo.DimProducto WHERE IdProductoOrigen=N'__PREC_E');
    DECLARE @pf int=(SELECT ProductoKey FROM dbo.DimProducto WHERE IdProductoOrigen=N'__PREC_F');
    ;WITH Digitos AS (SELECT n FROM (VALUES(0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) d(n)),
    Numeros AS (SELECT 1+a.n+10*b.n+100*c.n+1000*d.n AS n FROM Digitos a CROSS JOIN Digitos b CROSS JOIN Digitos c CROSS JOIN Digitos d)
    INSERT dbo.HechoOpinion(IdOpinionOrigen,CanalOrigen,ProductoKey,ClienteKey,FechaKey,FuenteKey,ClasificacionKey,FechaOpinion,Comentario,PuntajeSatisfaccion)
    SELECT CONCAT(N'__PREC_',v.ProductoKey,N'_',n.n),v.Canal,v.ProductoKey,@x,20250115,v.FuenteKey,
        CASE WHEN n.n=1 THEN 2 ELSE 1 END,'2025-01-15',N'Prueba temporal de precision',CASE WHEN n.n=1 THEN 4 ELSE 5 END
    FROM Numeros n CROSS JOIN (VALUES(@pe,2000,N'Web',@w1),(@pf,2001,N'Encuesta',@e)) v(ProductoKey,Cantidad,Canal,FuenteKey)
    WHERE n.n<=v.Cantidad;
    IF (SELECT COUNT(*) FROM dbo.vw_IndicadoresProducto WHERE PromedioSatisfaccion=4.999500)<>2
        THROW 51241,N'El escenario debe producir dos promedios iguales al mostrarlos con seis decimales.',1;
    INSERT @resultados(Prueba) VALUES(N'Promedios cercanos que coinciden al mostrarse');
    IF (SELECT COUNT(*) FROM dbo.vw_IndicadoresCanal WHERE PorcentajeNegativas=0.0500)<>2
        THROW 51241,N'El escenario debe producir dos porcentajes iguales al mostrarlos con cuatro decimales.',1;
    INSERT @resultados(Prueba) VALUES(N'Porcentajes cercanos que coinciden al mostrarse');
    IF NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE IdProductoOrigen=N'__PREC_E' AND OpinionesPuntuadas=2000 AND SumaPuntajes=9999)
        OR NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE IdProductoOrigen=N'__PREC_F' AND OpinionesPuntuadas=2001 AND SumaPuntajes=10004)
        THROW 51241,N'Los acumulados deben conservar los datos para comparar sin redondear.',1;
    INSERT @resultados(Prueba) VALUES(N'Acumulados exactos conservados para ranking');
    ROLLBACK TRANSACTION AntesPrecision;

    SAVE TRANSACTION AntesDesbalance;
    INSERT dbo.HechoOpinion(IdOpinionOrigen,CanalOrigen,ProductoKey,ClienteKey,FechaKey,FuenteKey,ClasificacionKey,FechaOpinion,Comentario,PuntajeSatisfaccion)
    VALUES (N'__CALC_11',N'Encuesta',@c,@y,20250116,@e,1,'2025-01-16',N'Prueba de ponderacion 11',4),
        (N'__CALC_12',N'Encuesta',@c,@y,20250116,@e,1,'2025-01-16',N'Prueba de ponderacion 12',4);
    IF NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE Comentarios=12 AND OpinionesPuntuadas=8 AND PromedioSatisfaccion=3.5)
        THROW 51241,N'El promedio general debe ponderar opiniones, no promedios por producto.',1;
    INSERT @resultados(Prueba) VALUES(N'Promedio ponderado con distintos tamanos de muestra');
    IF NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE OpinionesSatisfechas=6 AND PorcentajeSatisfaccion=75)
        THROW 51241,N'La satisfaccion debe usar las ocho opiniones puntuadas.',1;
    INSERT @resultados(Prueba) VALUES(N'Porcentaje ponderado con muestras desiguales');
    IF NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE IdProductoOrigen=N'__CALC_C' AND Comentarios=4 AND OpinionesPuntuadas=2 AND PromedioSatisfaccion=4 AND PorcentajeSatisfaccion=100)
        THROW 51241,N'El puntaje parcial del producto se calculo incorrectamente.',1;
    INSERT @resultados(Prueba) VALUES(N'Producto con mezcla de puntajes conocidos y NULL');
    ROLLBACK TRANSACTION AntesDesbalance;

    UPDATE dbo.HechoOpinion SET ClasificacionKey=0;

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE Pendientes=10 AND Positivas=0 AND Negativas=0 AND Neutras=0 AND CoberturaClasificacion=0))
        THROW 51241,N'Todo pendiente: cobertura cero sin opiniones neutras',1;
    INSERT @resultados(Prueba) VALUES(N'Todo pendiente: cobertura cero sin opiniones neutras');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_DistribucionClasificacion WHERE ClasificacionKey=0 AND Comentarios=10 AND PorcentajeTotal=100) AND NOT EXISTS(SELECT 1 FROM dbo.vw_DistribucionClasificacion WHERE ClasificacionKey<>0 AND Comentarios<>0))
        THROW 51241,N'Todo pendiente: porcentaje pendiente cien',1;
    INSERT @resultados(Prueba) VALUES(N'Todo pendiente: porcentaje pendiente cien');

    IF NOT (NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE Negativas>0) AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCanal WHERE Negativas>0))
        THROW 51241,N'Sin negativas no hay producto o canal ganador',1;
    INSERT @resultados(Prueba) VALUES(N'Sin negativas no hay producto o canal ganador');

    UPDATE dbo.HechoOpinion SET PuntajeSatisfaccion=NULL;

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE Comentarios=10 AND OpinionesPuntuadas=0 AND OpinionesSatisfechas=0 AND PromedioSatisfaccion IS NULL AND PorcentajeSatisfaccion IS NULL))
        THROW 51241,N'Todos los puntajes ausentes: promedio y satisfaccion NULL',1;
    INSERT @resultados(Prueba) VALUES(N'Todos los puntajes ausentes: promedio y satisfaccion NULL');

    IF NOT (NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE OpinionesPuntuadas>0) AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto WHERE PromedioSatisfaccion IS NOT NULL OR PorcentajeSatisfaccion IS NOT NULL))
        THROW 51241,N'Sin puntajes no hay producto mejor calificado',1;
    INSERT @resultados(Prueba) VALUES(N'Sin puntajes no hay producto mejor calificado');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE Comentarios=10 AND Pendientes=10 AND CoberturaClasificacion=0))
        THROW 51241,N'Quitar puntajes no cambia conteos ni sentimientos',1;
    INSERT @resultados(Prueba) VALUES(N'Quitar puntajes no cambia conteos ni sentimientos');

    DELETE FROM dbo.HechoOpinion;

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE Comentarios=0 AND OpinionesPuntuadas=0 AND OpinionesSatisfechas=0 AND Positivas=0 AND Negativas=0 AND Neutras=0 AND Pendientes=0))
        THROW 51241,N'General vacio: una fila con conteos cero con catalogos',1;
    INSERT @resultados(Prueba) VALUES(N'General vacio: una fila con conteos cero con catalogos');

    IF NOT (EXISTS(SELECT 1 FROM dbo.vw_IndicadoresGenerales WHERE PromedioSatisfaccion IS NULL AND PorcentajeSatisfaccion IS NULL AND PorcentajePositivas IS NULL AND PorcentajeNegativas IS NULL AND PorcentajeNeutras IS NULL AND CoberturaClasificacion IS NULL))
        THROW 51241,N'General vacio: promedios y porcentajes NULL con catalogos',1;
    INSERT @resultados(Prueba) VALUES(N'General vacio: promedios y porcentajes NULL con catalogos');

    IF NOT ((SELECT COUNT(*) FROM dbo.vw_DistribucionClasificacion)=4 AND NOT EXISTS(SELECT 1 FROM dbo.vw_DistribucionClasificacion WHERE Comentarios<>0 OR PorcentajeTotal IS NOT NULL))
        THROW 51241,N'Distribucion vacia mantiene cuatro estados con catalogos',1;
    INSERT @resultados(Prueba) VALUES(N'Distribucion vacia mantiene cuatro estados con catalogos');

    IF NOT (NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresProducto) AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresFuente) AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCanal) AND NOT EXISTS(SELECT 1 FROM dbo.vw_IndicadoresCliente) AND NOT EXISTS(SELECT 1 FROM dbo.vw_TendenciaMensual) AND NOT EXISTS(SELECT 1 FROM dbo.vw_TendenciaTrimestral) AND NOT EXISTS(SELECT 1 FROM dbo.vw_TendenciaProductoMensual))
        THROW 51241,N'Sin opiniones no hay grupos ni ganadores con catalogos',1;
    INSERT @resultados(Prueba) VALUES(N'Sin opiniones no hay grupos ni ganadores con catalogos');

    ROLLBACK TRANSACTION;
    IF EXISTS(SELECT 1 FROM dbo.HechoOpinion)
        THROW 51242,N'Las opiniones temporales no fueron revertidas.',1;
    SELECT Id,Prueba,N'OK' AS Resultado FROM @resultados ORDER BY Id;
    PRINT N'OK: 49 comprobaciones analiticas aprobadas con datos sinteticos revertidos. No son resultados del conjunto academico.';
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
