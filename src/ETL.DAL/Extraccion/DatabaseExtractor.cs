using System.Data;
using System.Runtime.CompilerServices;
using ETL.Entities.Contratos;
using Microsoft.Data.SqlClient;

namespace ETL.DAL.Extraccion;

public sealed class DatabaseExtractor : IExtractor
{
    private readonly string cadenaConexion;

    public DatabaseExtractor(string cadenaConexion)
    {
        var configuracion = new SqlConnectionStringBuilder(cadenaConexion)
        {
            PersistSecurityInfo = false
        };
        if (configuracion.Encrypt == SqlConnectionEncryptOption.Optional)
            throw new ArgumentException("La conexión SQL debe exigir cifrado.", nameof(cadenaConexion));

        this.cadenaConexion = configuracion.ConnectionString;
    }

    public string Fuente => "resenas-sql";

    public async IAsyncEnumerable<IReadOnlyDictionary<string, object?>> ExtraerAsync(
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        await using var conexion = new SqlConnection(cadenaConexion);
        await conexion.OpenAsync(cancellationToken);

        await using var consulta = conexion.CreateCommand();
        consulta.CommandText = """
            SELECT IdExterno AS IdReview, IdClienteOrigen AS IdCliente,
                   IdProductoOrigen AS IdProducto, Fecha, Comentario,
                   PuntajeSatisfaccion AS Rating
            FROM dbo.vw_OpinionesDetalle
            WHERE Canal = @Canal
            ORDER BY IdExterno;
            """;
        consulta.Parameters.Add("@Canal", SqlDbType.NVarChar, 20).Value = "Web";
        consulta.CommandTimeout = 60;

        await using var lector = await consulta.ExecuteReaderAsync(
            CommandBehavior.SequentialAccess, cancellationToken);
        var columnas = Enumerable.Range(0, lector.FieldCount).Select(lector.GetName).ToArray();
        while (await lector.ReadAsync(cancellationToken))
        {
            var registro = new Dictionary<string, object?>(columnas.Length, StringComparer.Ordinal);
            for (var indice = 0; indice < columnas.Length; indice++)
            {
                var valor = await lector.GetFieldValueAsync<object>(indice, cancellationToken);
                registro.Add(columnas[indice], valor is DBNull ? null : valor);
            }

            yield return registro;
        }
    }
}
