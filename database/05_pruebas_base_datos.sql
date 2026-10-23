USE AnalisisOpinionesClientes;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @cliente int, @producto int, @fuente int, @social int, @opinion bigint, @estado varchar(10);
    EXEC dbo.usp_CargarCliente N'__PRUEBA_CLIENTE', N'Cliente temporal', NULL, @cliente OUTPUT, @estado OUTPUT;
    IF @estado <> 'Insertado' THROW 51100, N'No se inserto el cliente temporal.', 1;
    EXEC dbo.usp_CargarCliente N'__PRUEBA_CLIENTE', N'Cliente temporal', NULL, @cliente OUTPUT, @estado OUTPUT;
    IF @estado <> 'Omitido' THROW 51101, N'No se omitio el duplicado.', 1;
    EXEC dbo.usp_CargarCliente N'__PRUEBA_CLIENTE', N'Otro nombre', NULL, @cliente OUTPUT, @estado OUTPUT;
    IF @estado <> 'Conflicto' THROW 51102, N'No se detecto el conflicto.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Clientes WHERE IdCliente=@cliente AND Nombre<>N'Cliente temporal')
        THROW 51103, N'El conflicto sobrescribio datos.', 1;
    EXEC dbo.usp_CargarProducto N'__PRUEBA_PRODUCTO', N'Producto temporal', N'Prueba', @producto OUTPUT, @estado OUTPUT;
    EXEC dbo.usp_CargarFuente N'__PRUEBA_WEB', N'Web', '2026-10-23', @fuente OUTPUT, @estado OUTPUT;
    EXEC dbo.usp_CargarFuente N'__PRUEBA_RED', N'Red Social', '2026-10-23', @social OUTPUT, @estado OUTPUT;
    EXEC dbo.usp_CargarOpinion N'__PRUEBA_OPINION', N'Web', @cliente, @producto, @fuente, '2026-10-23', N'Comentario temporal', NULL, 4, N'C001', N'P001', @opinion OUTPUT, @estado OUTPUT;
    IF @estado <> 'Insertado' THROW 51104, N'No se inserto la opinion temporal.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Opiniones WHERE IdOpinion=@opinion AND Clasificacion IS NULL)
        THROW 51105, N'No se conservo la clasificacion pendiente.', 1;
    EXEC dbo.usp_CargarOpinion N'__PRUEBA_OPINION', N'Web', @cliente, @producto, @fuente, '2026-10-23', N'Comentario temporal', NULL, 4, N'C001', N'P001', @opinion OUTPUT, @estado OUTPUT;
    IF @estado <> 'Omitido' THROW 51106, N'No se omitio la opinion repetida.', 1;
    EXEC dbo.usp_CargarOpinion N'__PRUEBA_OPINION', N'Web', @cliente, @producto, @fuente, '2026-10-23', N'Comentario cambiado', NULL, 4, N'C001', N'P001', @opinion OUTPUT, @estado OUTPUT;
    IF @estado <> 'Conflicto' THROW 51107, N'No se detecto el conflicto de opinion.', 1;
    EXEC dbo.usp_CargarOpinion N'__PRUEBA_OPINION', N'RedSocial', NULL, @producto, @social, '2026-10-23', N'Comentario social temporal', NULL, NULL, NULL, N'P001', @opinion OUTPUT, @estado OUTPUT;
    IF @estado <> 'Insertado' THROW 51108, N'El ID por canal o cliente opcional no funciona.', 1;
    IF EXISTS (SELECT 1 FROM dbo.vw_CalidadReferencial WHERE ClienteHuerfano=1 OR ProductoHuerfano=1 OR FuenteHuerfana=1)
        THROW 51109, N'La vista encontro referencias huerfanas.', 1;
    IF (SELECT SUM(PendientesClasificacion) FROM dbo.vw_ResumenCargaPorCanal) <> (SELECT COUNT_BIG(*) FROM dbo.Opiniones WHERE Clasificacion IS NULL)
        THROW 51110, N'El resumen de pendientes no cuadra.', 1;
    ROLLBACK TRANSACTION;
    PRINT N'OK: insercion, duplicados, conflictos, ID por canal, cliente opcional y clasificacion pendiente; datos revertidos.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.Clientes(Nombre, Email, IdExterno) VALUES(N'Cliente temporal', NULL, N'__PRUEBA_CLIENTE');
    DECLARE @cliente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Productos(Nombre, Categoria, IdExterno) VALUES(N'Producto temporal', N'Prueba', N'__PRUEBA_PRODUCTO');
    DECLARE @producto int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.FuenteDatos(TipoFuente, FechaCarga, IdExterno) VALUES(N'Web', '2026-10-23', N'__PRUEBA_WEB');
    DECLARE @fuente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Opiniones(IdCliente,IdProducto,IdFuente,Fecha,Comentario,Clasificacion,PuntajeSatisfaccion,IdExterno,Canal,IdClienteOrigen,IdProductoOrigen) VALUES (-1,@producto,@fuente,'2026-10-23',N'Comentario temporal',NULL,4,N'__PRUEBA_OPINION',N'Web',N'C001',N'P001');
    ROLLBACK TRANSACTION;
    THROW 51200, N'La prueba FK cliente debio rechazar la entrada.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (547) THROW;
    PRINT N'OK: FK cliente; datos revertidos.';
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.Clientes(Nombre, Email, IdExterno) VALUES(N'Cliente temporal', NULL, N'__PRUEBA_CLIENTE');
    DECLARE @cliente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Productos(Nombre, Categoria, IdExterno) VALUES(N'Producto temporal', N'Prueba', N'__PRUEBA_PRODUCTO');
    DECLARE @producto int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.FuenteDatos(TipoFuente, FechaCarga, IdExterno) VALUES(N'Web', '2026-10-23', N'__PRUEBA_WEB');
    DECLARE @fuente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Opiniones(IdCliente,IdProducto,IdFuente,Fecha,Comentario,Clasificacion,PuntajeSatisfaccion,IdExterno,Canal,IdClienteOrigen,IdProductoOrigen) VALUES (@cliente,-1,@fuente,'2026-10-23',N'Comentario temporal',NULL,4,N'__PRUEBA_OPINION',N'Web',N'C001',N'P001');
    ROLLBACK TRANSACTION;
    THROW 51200, N'La prueba FK producto debio rechazar la entrada.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (547) THROW;
    PRINT N'OK: FK producto; datos revertidos.';
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.Clientes(Nombre, Email, IdExterno) VALUES(N'Cliente temporal', NULL, N'__PRUEBA_CLIENTE');
    DECLARE @cliente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Productos(Nombre, Categoria, IdExterno) VALUES(N'Producto temporal', N'Prueba', N'__PRUEBA_PRODUCTO');
    DECLARE @producto int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.FuenteDatos(TipoFuente, FechaCarga, IdExterno) VALUES(N'Web', '2026-10-23', N'__PRUEBA_WEB');
    DECLARE @fuente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Opiniones(IdCliente,IdProducto,IdFuente,Fecha,Comentario,Clasificacion,PuntajeSatisfaccion,IdExterno,Canal,IdClienteOrigen,IdProductoOrigen) VALUES (@cliente,@producto,-1,'2026-10-23',N'Comentario temporal',NULL,4,N'__PRUEBA_OPINION',N'Web',N'C001',N'P001');
    ROLLBACK TRANSACTION;
    THROW 51200, N'La prueba FK fuente debio rechazar la entrada.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (547) THROW;
    PRINT N'OK: FK fuente; datos revertidos.';
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.Clientes(Nombre, Email, IdExterno) VALUES(N'Cliente temporal', NULL, N'__PRUEBA_CLIENTE');
    DECLARE @cliente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Productos(Nombre, Categoria, IdExterno) VALUES(N'Producto temporal', N'Prueba', N'__PRUEBA_PRODUCTO');
    DECLARE @producto int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.FuenteDatos(TipoFuente, FechaCarga, IdExterno) VALUES(N'Web', '2026-10-23', N'__PRUEBA_WEB');
    DECLARE @fuente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Opiniones(IdCliente,IdProducto,IdFuente,Fecha,Comentario,Clasificacion,PuntajeSatisfaccion,IdExterno,Canal,IdClienteOrigen,IdProductoOrigen) VALUES (@cliente,@producto,@fuente,'2026-10-23',N'Comentario temporal',NULL,0,N'__PRUEBA_OPINION',N'Web',N'C001',N'P001');
    ROLLBACK TRANSACTION;
    THROW 51200, N'La prueba rango satisfaccion debio rechazar la entrada.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (547) THROW;
    PRINT N'OK: rango satisfaccion; datos revertidos.';
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.Clientes(Nombre, Email, IdExterno) VALUES(N'Cliente temporal', NULL, N'__PRUEBA_CLIENTE');
    DECLARE @cliente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Productos(Nombre, Categoria, IdExterno) VALUES(N'Producto temporal', N'Prueba', N'__PRUEBA_PRODUCTO');
    DECLARE @producto int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.FuenteDatos(TipoFuente, FechaCarga, IdExterno) VALUES(N'Web', '2026-10-23', N'__PRUEBA_WEB');
    DECLARE @fuente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Opiniones(IdCliente,IdProducto,IdFuente,Fecha,Comentario,Clasificacion,PuntajeSatisfaccion,IdExterno,Canal,IdClienteOrigen,IdProductoOrigen) VALUES (@cliente,@producto,@fuente,'2026-10-23',N'Comentario temporal',N'Incorrecta',4,N'__PRUEBA_OPINION',N'Web',N'C001',N'P001');
    ROLLBACK TRANSACTION;
    THROW 51200, N'La prueba clasificacion invalida debio rechazar la entrada.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (547) THROW;
    PRINT N'OK: clasificacion invalida; datos revertidos.';
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.Clientes(Nombre, Email, IdExterno) VALUES(N'Cliente temporal', NULL, N'__PRUEBA_CLIENTE');
    DECLARE @cliente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Productos(Nombre, Categoria, IdExterno) VALUES(N'Producto temporal', N'Prueba', N'__PRUEBA_PRODUCTO');
    DECLARE @producto int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.FuenteDatos(TipoFuente, FechaCarga, IdExterno) VALUES(N'Web', '2026-10-23', N'__PRUEBA_WEB');
    DECLARE @fuente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Opiniones(IdCliente,IdProducto,IdFuente,Fecha,Comentario,Clasificacion,PuntajeSatisfaccion,IdExterno,Canal,IdClienteOrigen,IdProductoOrigen) VALUES (@cliente,@producto,@fuente,'2026-10-23',N'Comentario temporal',NULL,4,N'__PRUEBA_OPINION',N'Otro',N'C001',N'P001');
    ROLLBACK TRANSACTION;
    THROW 51200, N'La prueba canal invalido debio rechazar la entrada.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (547) THROW;
    PRINT N'OK: canal invalido; datos revertidos.';
END CATCH;
GO

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.Clientes(Nombre, Email, IdExterno) VALUES(N'Cliente temporal', NULL, N'__PRUEBA_CLIENTE');
    DECLARE @cliente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Productos(Nombre, Categoria, IdExterno) VALUES(N'Producto temporal', N'Prueba', N'__PRUEBA_PRODUCTO');
    DECLARE @producto int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.FuenteDatos(TipoFuente, FechaCarga, IdExterno) VALUES(N'Web', '2026-10-23', N'__PRUEBA_WEB');
    DECLARE @fuente int=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.Opiniones(IdCliente,IdProducto,IdFuente,Fecha,Comentario,Clasificacion,PuntajeSatisfaccion,IdExterno,Canal,IdClienteOrigen,IdProductoOrigen) VALUES (@cliente,@producto,@fuente,'2026-10-23',N'Comentario temporal',NULL,4,N'__PRUEBA_OPINION',N'Web',N'C001',N'P001');
    INSERT dbo.Opiniones(IdCliente,IdProducto,IdFuente,Fecha,Comentario,Clasificacion,PuntajeSatisfaccion,IdExterno,Canal,IdClienteOrigen,IdProductoOrigen) VALUES (@cliente,@producto,@fuente,'2026-10-23',N'Comentario temporal',NULL,4,N'__PRUEBA_OPINION',N'Web',N'C001',N'P001');
    ROLLBACK TRANSACTION;
    THROW 51200, N'La prueba clave externa unica debio rechazar la entrada.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (2601,2627) THROW;
    PRINT N'OK: clave externa unica; datos revertidos.';
END CATCH;
GO

BEGIN TRY
    DECLARE @id int, @estado varchar(10);
    EXEC dbo.usp_CargarCliente N'__PRUEBA_SIN_TRANSACCION', N'Temporal', NULL, @id OUTPUT, @estado OUTPUT;
    THROW 51201, N'El procedimiento debio exigir una transaccion.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 51010 THROW;
    PRINT N'OK: contrato de transaccion del llamador.';
END CATCH;
GO
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @producto int, @fuente int, @opinion bigint, @estado varchar(10);
    EXEC dbo.usp_CargarProducto N'__PRUEBA_PRODUCTO', N'Producto temporal', N'Prueba', @producto OUTPUT, @estado OUTPUT;
    EXEC dbo.usp_CargarFuente N'__PRUEBA_FUENTE', N'CSV', '2026-10-23', @fuente OUTPUT, @estado OUTPUT;
    EXEC dbo.usp_CargarOpinion N'__PRUEBA_CANAL', N'Web', NULL, @producto, @fuente, '2026-10-23', N'Temporal', NULL, 4, NULL, N'P001', @opinion OUTPUT, @estado OUTPUT;
    ROLLBACK TRANSACTION;
    THROW 51202, N'La fuente incompatible debio rechazarse.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 51011 THROW;
    PRINT N'OK: fuente compatible con canal; datos revertidos.';
END CATCH;
GO
IF EXISTS (SELECT 1 FROM dbo.Clientes WHERE IdExterno LIKE N'[_][_]PRUEBA%')
 OR EXISTS (SELECT 1 FROM dbo.Productos WHERE IdExterno LIKE N'[_][_]PRUEBA%')
 OR EXISTS (SELECT 1 FROM dbo.FuenteDatos WHERE IdExterno LIKE N'[_][_]PRUEBA%')
 OR EXISTS (SELECT 1 FROM dbo.Opiniones WHERE IdExterno LIKE N'[_][_]PRUEBA%')
    THROW 51203, N'Quedaron datos temporales de prueba.', 1;
PRINT N'OK: no quedaron registros temporales.';
GO
