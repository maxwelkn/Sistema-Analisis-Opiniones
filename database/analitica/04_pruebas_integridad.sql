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
    THROW 51230,N'Ejecute las pruebas fuera de una transaccion existente.',1;
IF EXISTS(SELECT 1 FROM dbo.DimProducto WHERE IdProductoOrigen=N'__PRUEBA_PRODUCTO')
    OR EXISTS(SELECT 1 FROM dbo.DimCliente WHERE IdClienteOrigen=N'__PRUEBA_CLIENTE')
    OR EXISTS(SELECT 1 FROM dbo.DimFecha WHERE FechaKey IN(20261030,20240229))
    OR EXISTS(SELECT 1 FROM dbo.DimFuente WHERE IdFuenteOrigen IN(N'__PRUEBA_WEB',N'__PRUEBA_RED'))
    THROW 51230,N'Las claves reservadas de prueba ya existen. No se borraran datos; revise el escenario.',1;

DECLARE @casos table(Id int IDENTITY,Nombre nvarchar(120),Sentencia nvarchar(max),ErrorEsperado int NULL);
INSERT @casos(Nombre,Sentencia,ErrorEsperado) VALUES
    (N'Opinion valida y hechos individuales',N'INSERT dbo.HechoOpinion(IdOpinionOrigen,CanalOrigen,ProductoKey,ClienteKey,FechaKey,FuenteKey,ClasificacionKey,FechaOpinion,Comentario,PuntajeSatisfaccion) VALUES(N''__OTRA'',N''Web'',@p,@c,20261030,@w,1,''2026-10-30'',N''Otra opinion'',5); IF (SELECT COUNT(*) FROM dbo.HechoOpinion WHERE ProductoKey=@p)<>2 THROW 51231,N''No se preservo el grano individual.'',1;',NULL),
    (N'Cliente desconocido y puntaje ausente',N'UPDATE dbo.HechoOpinion SET ClienteKey=0,ClasificacionKey=0,PuntajeSatisfaccion=NULL WHERE OpinionKey=@o; IF NOT EXISTS(SELECT 1 FROM dbo.HechoOpinion WHERE OpinionKey=@o AND ClienteKey=0 AND ClasificacionKey=0 AND PuntajeSatisfaccion IS NULL) THROW 51231,N''No se preservaron desconocidos.'',1;',NULL),
    (N'Mismo identificador en distinto canal',N'INSERT dbo.HechoOpinion(IdOpinionOrigen,CanalOrigen,ProductoKey,ClienteKey,FechaKey,FuenteKey,ClasificacionKey,FechaOpinion,Comentario,PuntajeSatisfaccion) VALUES(N''__PRUEBA_OPINION'',N''RedSocial'',@p,0,20261030,@r,0,''2026-10-30'',N''Opinion social temporal'',NULL);',NULL),
    (N'Calendario calculado y anio bisiesto',N'INSERT dbo.DimFecha(FechaKey,Fecha) VALUES(20240229,''2024-02-29''); IF NOT EXISTS(SELECT 1 FROM dbo.DimFecha WHERE FechaKey=20240229 AND Anio=2024 AND Trimestre=1 AND Mes=2 AND Dia=29) THROW 51231,N''Calendario incoherente.'',1;',NULL),
    (N'Puntajes extremos validos',N'UPDATE dbo.HechoOpinion SET PuntajeSatisfaccion=1 WHERE OpinionKey=@o; UPDATE dbo.HechoOpinion SET PuntajeSatisfaccion=5 WHERE OpinionKey=@o;',NULL),
    (N'Texto LOB en FG_Hechos',N'UPDATE dbo.HechoOpinion SET Comentario=REPLICATE(CONVERT(nvarchar(max),N''X''),12000) WHERE OpinionKey=@o; IF (SELECT DATALENGTH(Comentario) FROM dbo.HechoOpinion WHERE OpinionKey=@o)<>24000 THROW 51231,N''Texto largo truncado.'',1; IF NOT EXISTS(SELECT 1 FROM sys.allocation_units a JOIN sys.partitions p ON a.container_id=p.partition_id JOIN sys.filegroups g ON a.data_space_id=g.data_space_id WHERE p.object_id=OBJECT_ID(N''dbo.HechoOpinion'') AND a.type=2 AND a.total_pages>0 AND g.name=N''FG_Hechos'') THROW 51231,N''LOB fuera de FG_Hechos.'',1;',NULL),
    (N'Origen de opinion duplicado',N'INSERT dbo.HechoOpinion(IdOpinionOrigen,CanalOrigen,ProductoKey,ClienteKey,FechaKey,FuenteKey,ClasificacionKey,FechaOpinion,Comentario) VALUES(N''__PRUEBA_OPINION'',N''Web'',@p,@c,20261030,@w,0,''2026-10-30'',N''Duplicada'');',2627),
    (N'Producto ausente',N'UPDATE dbo.HechoOpinion SET ProductoKey=-1 WHERE OpinionKey=@o;',547),
    (N'Cliente informado ausente',N'UPDATE dbo.HechoOpinion SET ClienteKey=-1 WHERE OpinionKey=@o;',547),
    (N'Fecha ausente',N'UPDATE dbo.HechoOpinion SET FechaKey=20261029,FechaOpinion=''2026-10-29'' WHERE OpinionKey=@o;',547),
    (N'Fuente ausente',N'UPDATE dbo.HechoOpinion SET FuenteKey=-1 WHERE OpinionKey=@o;',547),
    (N'Clasificacion ausente',N'UPDATE dbo.HechoOpinion SET ClasificacionKey=255 WHERE OpinionKey=@o;',547),
    (N'Canal distinto al de fuente',N'UPDATE dbo.HechoOpinion SET CanalOrigen=N''RedSocial'' WHERE OpinionKey=@o;',547),
    (N'Puntaje cero',N'UPDATE dbo.HechoOpinion SET PuntajeSatisfaccion=0 WHERE OpinionKey=@o;',547),
    (N'Puntaje seis',N'UPDATE dbo.HechoOpinion SET PuntajeSatisfaccion=6 WHERE OpinionKey=@o;',547),
    (N'Comentario vacio',N'UPDATE dbo.HechoOpinion SET Comentario=N'''' WHERE OpinionKey=@o;',547),
    (N'Comentario solo espacios',N'UPDATE dbo.HechoOpinion SET Comentario=N''   '' WHERE OpinionKey=@o;',547),
    (N'Identificador vacio',N'UPDATE dbo.HechoOpinion SET IdOpinionOrigen=N'' '' WHERE OpinionKey=@o;',547),
    (N'FechaOpinion distinta a FechaKey',N'UPDATE dbo.HechoOpinion SET FechaOpinion=''2026-10-29'' WHERE OpinionKey=@o;',547),
    (N'Clave de fecha incoherente',N'INSERT dbo.DimFecha(FechaKey,Fecha) VALUES(20261031,''2026-10-29'');',547),
    (N'Cliente real sin identificador',N'INSERT dbo.DimCliente(Nombre) VALUES(N''Cliente temporal sin ID'');',547),
    (N'Cliente real sin nombre',N'INSERT dbo.DimCliente(IdClienteOrigen) VALUES(N''__SIN_NOMBRE'');',547),
    (N'Miembro desconocido con datos personales',N'UPDATE dbo.DimCliente SET Nombre=N''Persona inventada'' WHERE ClienteKey=0;',547),
    (N'Nombre de clasificacion incompatible',N'UPDATE dbo.DimClasificacion SET Nombre=N''SinEstado'' WHERE ClasificacionKey=0;',547),
    (N'Tipo de fuente incompatible',N'UPDATE dbo.DimFuente SET TipoFuente=N''CSV'' WHERE FuenteKey=@w;',547),
    (N'Canal no permitido',N'INSERT dbo.DimFuente(IdFuenteOrigen,Canal,TipoFuente) VALUES(N''__OTRA'',N''Otro'',N''Web'');',547),
    (N'Producto de origen duplicado',N'INSERT dbo.DimProducto(IdProductoOrigen,Nombre,Categoria) VALUES(N''__PRUEBA_PRODUCTO'',N''Producto'',N''Prueba'');',2627),
    (N'Cliente de origen duplicado',N'INSERT dbo.DimCliente(IdClienteOrigen,Nombre) VALUES(N''__PRUEBA_CLIENTE'',N''Cliente'');',2601),
    (N'Fuente de origen duplicada',N'INSERT dbo.DimFuente(IdFuenteOrigen,Canal,TipoFuente) VALUES(N''__PRUEBA_WEB'',N''Web'',N''Web'');',2627),
    (N'Fecha nula',N'UPDATE dbo.HechoOpinion SET FechaOpinion=NULL WHERE OpinionKey=@o;',515),
    (N'Nombre de producto vacio',N'UPDATE dbo.DimProducto SET Nombre=N''  '' WHERE ProductoKey=@p;',547),
    (N'Segmento vacio',N'UPDATE dbo.DimCliente SET Pais=N''  '' WHERE ClienteKey=@c;',547);

DECLARE @preparacion nvarchar(max)=N'INSERT dbo.DimProducto(IdProductoOrigen,Nombre,Categoria) VALUES(N''__PRUEBA_PRODUCTO'',N''Producto temporal'',N''Prueba'');
DECLARE @p int=CONVERT(int,SCOPE_IDENTITY());
INSERT dbo.DimCliente(IdClienteOrigen,Nombre) VALUES(N''__PRUEBA_CLIENTE'',N''Cliente temporal'');
DECLARE @c int=CONVERT(int,SCOPE_IDENTITY());
INSERT dbo.DimFecha(FechaKey,Fecha) VALUES(20261030,''2026-10-30'');
INSERT dbo.DimFuente(IdFuenteOrigen,Canal,TipoFuente) VALUES(N''__PRUEBA_WEB'',N''Web'',N''Web'');
DECLARE @w int=CONVERT(int,SCOPE_IDENTITY());
INSERT dbo.DimFuente(IdFuenteOrigen,Canal,TipoFuente) VALUES(N''__PRUEBA_RED'',N''RedSocial'',N''Red Social'');
DECLARE @r int=CONVERT(int,SCOPE_IDENTITY());
INSERT dbo.HechoOpinion(IdOpinionOrigen,CanalOrigen,ProductoKey,ClienteKey,FechaKey,FuenteKey,ClasificacionKey,FechaOpinion,Comentario,PuntajeSatisfaccion)
VALUES(N''__PRUEBA_OPINION'',N''Web'',@p,@c,20261030,@w,0,''2026-10-30'',N''Comentario temporal de prueba'',4);
DECLARE @o bigint=CONVERT(bigint,SCOPE_IDENTITY());
';
DECLARE @resultados table(Id int,Prueba nvarchar(120),ErrorEsperado int NULL,ErrorObservado int NULL);
DECLARE @id int=1,@total int=(SELECT COUNT(*) FROM @casos),@nombre nvarchar(120),@sentencia nvarchar(max),@esperado int;
WHILE @id<=@total
BEGIN
    SELECT @nombre=Nombre,@sentencia=Sentencia,@esperado=ErrorEsperado FROM @casos WHERE Id=@id;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ejecucion nvarchar(max)=@preparacion+@sentencia;
        EXEC sys.sp_executesql @ejecucion;
        IF @esperado IS NOT NULL
            THROW 51232,N'Una entrada invalida fue aceptada.',1;
        ROLLBACK TRANSACTION;
        INSERT @resultados VALUES(@id,@nombre,@esperado,NULL);
    END TRY
    BEGIN CATCH
        DECLARE @observado int=ERROR_NUMBER();
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        IF @esperado IS NULL OR @observado<>@esperado
        BEGIN
            PRINT @nombre;
            THROW;
        END;
        INSERT @resultados VALUES(@id,@nombre,@esperado,@observado);
    END CATCH;
    SET @id+=1;
END;
SELECT Id,Prueba,ErrorEsperado,ErrorObservado,N'OK' AS Resultado FROM @resultados ORDER BY Id;
PRINT N'OK: 32 pruebas de integridad. Todos los registros de prueba fueron revertidos; IDENTITY puede tener saltos.';
GO
