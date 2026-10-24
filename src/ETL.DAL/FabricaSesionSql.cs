using System.Data;
using ETL.Entities.Carga;
using ETL.Entities.Contratos;
using Microsoft.Data.SqlClient;

namespace ETL.DAL;

public sealed class FabricaSesionSql : IFabricaSesionCarga
{
    private readonly string cadenaConexion;

    public FabricaSesionSql(string cadenaConexion)
    {
        try
        {
            var configuracion = new SqlConnectionStringBuilder(cadenaConexion);
            if (string.IsNullOrWhiteSpace(configuracion.InitialCatalog))
                throw new ArgumentException("Se requiere una base de datos explicita.");
            this.cadenaConexion = configuracion.ConnectionString;
        }
        catch (ArgumentException error)
        {
            throw new ErrorPersistenciaException("Configuracion SQL no valida.", error);
        }
    }

    public async Task<ISesionCarga> AbrirAsync(CancellationToken cancellationToken = default)
    {
        var conexion = new SqlConnection(cadenaConexion);
        try
        {
            await conexion.OpenAsync(cancellationToken);
            var transaccion = (SqlTransaction)await conexion.BeginTransactionAsync(
                IsolationLevel.ReadCommitted, cancellationToken);
            return new SesionCargaSql(conexion, transaccion);
        }
        catch (Exception error)
        {
            await conexion.DisposeAsync();
            if (error is OperationCanceledException)
                throw;
            throw new ErrorPersistenciaException("No se pudo abrir la sesion SQL.", error);
        }
    }
}
