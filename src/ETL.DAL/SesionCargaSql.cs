using System.Data;
using ETL.Entities;
using ETL.Entities.Carga;
using ETL.Entities.Contratos;
using Microsoft.Data.SqlClient;

namespace ETL.DAL;

internal sealed class SesionCargaSql(SqlConnection conexion, SqlTransaction transaccion) : ISesionCarga
{
    private bool finalizada;
    private bool liberada;

    public async Task<FuenteDatos?> ObtenerFuenteAsync(
        string idExterno, CancellationToken cancellationToken = default)
    {
        using var comando = CrearComando("SELECT IdExterno, TipoFuente, FechaCarga FROM dbo.FuenteDatos WITH (UPDLOCK, HOLDLOCK) WHERE IdExterno = @IdExterno;");
        comando.CommandType = CommandType.Text;
        Texto(comando, "@IdExterno", 100, idExterno);
        try
        {
            await using var lector = await comando.ExecuteReaderAsync(cancellationToken);
            return await lector.ReadAsync(cancellationToken)
                ? new(lector.GetString(0), lector.GetString(1), lector.GetDateTime(2)) : null;
        }
        catch (SqlException error)
        {
            throw new ErrorPersistenciaException("No se pudo consultar la fuente SQL.", error);
        }
    }

    public Task<ResultadoPersistencia<int>> CargarClienteAsync(
        Cliente cliente, CancellationToken cancellationToken = default) =>
        EjecutarAsync<int>("dbo.usp_CargarCliente", "@IdClienteResultado", SqlDbType.Int, comando =>
        {
            Texto(comando, "@IdExterno", 50, cliente.IdExterno);
            Texto(comando, "@Nombre", 120, cliente.Nombre);
            Texto(comando, "@Email", 254, cliente.Email);
        }, cancellationToken);

    public Task<ResultadoPersistencia<int>> CargarProductoAsync(
        Producto producto, CancellationToken cancellationToken = default) =>
        EjecutarAsync<int>("dbo.usp_CargarProducto", "@IdProductoResultado", SqlDbType.Int, comando =>
        {
            Texto(comando, "@IdExterno", 50, producto.IdExterno);
            Texto(comando, "@Nombre", 150, producto.Nombre);
            Texto(comando, "@Categoria", 100, producto.Categoria);
        }, cancellationToken);

    public Task<ResultadoPersistencia<int>> CargarFuenteAsync(
        FuenteDatos fuente, CancellationToken cancellationToken = default) =>
        EjecutarAsync<int>("dbo.usp_CargarFuente", "@IdFuenteResultado", SqlDbType.Int, comando =>
        {
            Texto(comando, "@IdExterno", 100, fuente.IdExterno);
            Texto(comando, "@TipoFuente", 50, fuente.TipoFuente);
            Fecha(comando, "@FechaCarga", fuente.FechaCarga);
        }, cancellationToken);

    public Task<ResultadoPersistencia<long>> CargarOpinionAsync(
        Opinion opinion, CancellationToken cancellationToken = default) =>
        EjecutarAsync<long>("dbo.usp_CargarOpinion", "@IdOpinionResultado", SqlDbType.BigInt, comando =>
        {
            Texto(comando, "@IdExterno", 50, opinion.IdExterno);
            Texto(comando, "@Canal", 20, opinion.Canal);
            Valor(comando, "@IdCliente", SqlDbType.Int, opinion.IdCliente);
            Valor(comando, "@IdProducto", SqlDbType.Int, opinion.IdProducto);
            Valor(comando, "@IdFuente", SqlDbType.Int, opinion.IdFuente);
            Fecha(comando, "@Fecha", opinion.Fecha);
            Texto(comando, "@Comentario", -1, opinion.Comentario);
            Texto(comando, "@Clasificacion", 10, opinion.Clasificacion);
            Valor(comando, "@PuntajeSatisfaccion", SqlDbType.TinyInt, opinion.PuntajeSatisfaccion);
            Texto(comando, "@IdClienteOrigen", 50, opinion.IdClienteOrigen);
            Texto(comando, "@IdProductoOrigen", 50, opinion.IdProductoOrigen);
        }, cancellationToken);

    public async Task ConfirmarAsync(CancellationToken cancellationToken = default)
    {
        VerificarActiva();
        try
        {
            await transaccion.CommitAsync(cancellationToken);
            finalizada = true;
        }
        catch (Exception error) when (error is SqlException or InvalidOperationException)
        {
            throw new ErrorPersistenciaException("No se pudo confirmar la transaccion SQL.", error);
        }
    }

    public async Task RevertirAsync(CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(liberada, this);
        if (finalizada)
            return;
        try
        {
            if (transaccion.Connection is not null)
                await transaccion.RollbackAsync(cancellationToken);
            finalizada = true;
        }
        catch (Exception error) when (error is SqlException or InvalidOperationException)
        {
            throw new ErrorPersistenciaException("No se pudo verificar la reversion SQL.", error);
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (liberada)
            return;
        liberada = true;
        try
        {
            try
            {
                await transaccion.DisposeAsync();
            }
            finally
            {
                await conexion.DisposeAsync();
            }
        }
        catch (Exception error) when (error is SqlException or InvalidOperationException)
        {
            throw new ErrorPersistenciaException("No se pudo liberar la sesion SQL.", error);
        }
    }

    private async Task<ResultadoPersistencia<TId>> EjecutarAsync<TId>(
        string procedimiento, string parametroId, SqlDbType tipoId,
        Action<SqlCommand> completar, CancellationToken cancellationToken) where TId : struct
    {
        using var comando = CrearComando(procedimiento);
        completar(comando);
        var id = comando.Parameters.Add(parametroId, tipoId);
        id.Direction = ParameterDirection.Output;
        var estado = comando.Parameters.Add("@Estado", SqlDbType.VarChar, 10);
        estado.Direction = ParameterDirection.Output;
        try
        {
            await comando.ExecuteNonQueryAsync(cancellationToken);
            var resultado = estado.Value switch
            {
                "Insertado" => EstadoPersistencia.Insertado,
                "Omitido" => EstadoPersistencia.Omitido,
                "Conflicto" => EstadoPersistencia.Conflicto,
                _ => throw new ErrorPersistenciaException("SQL devolvio un estado de carga no reconocido.")
            };
            if (id.Value is not TId clave)
                throw new ErrorPersistenciaException("SQL no devolvio una clave interna del tipo esperado.");
            return new(clave, resultado);
        }
        catch (SqlException error)
        {
            throw new ErrorPersistenciaException("Fallo al persistir un registro en SQL.", error);
        }
    }

    private SqlCommand CrearComando(string texto)
    {
        VerificarActiva();
        return new(texto, conexion, transaccion) { CommandType = CommandType.StoredProcedure };
    }

    private void VerificarActiva()
    {
        ObjectDisposedException.ThrowIf(liberada, this);
        if (finalizada)
            throw new InvalidOperationException("La sesion de carga ya termino.");
    }

    private static void Texto(SqlCommand comando, string nombre, int longitud, string? valor)
    {
        if (valor is not null && longitud >= 0 && valor.Length > longitud)
            throw new ErrorPersistenciaException("Un texto excede la longitud del parametro SQL.");
        comando.Parameters.Add(nombre, SqlDbType.NVarChar, longitud).Value = (object?)valor ?? DBNull.Value;
    }

    private static void Valor(SqlCommand comando, string nombre, SqlDbType tipo, object? valor) =>
        comando.Parameters.Add(nombre, tipo).Value = valor ?? DBNull.Value;

    private static void Fecha(SqlCommand comando, string nombre, DateTime valor)
    {
        if (valor.Ticks % TimeSpan.TicksPerSecond != 0)
            throw new ErrorPersistenciaException("La fecha debe tener precision de segundos para SQL.");
        var parametro = comando.Parameters.Add(nombre, SqlDbType.DateTime2);
        parametro.Scale = 0;
        parametro.Value = valor;
    }
}
