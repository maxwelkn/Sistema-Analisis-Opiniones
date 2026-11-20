using System.Runtime.CompilerServices;
using ETL.Entities.Contratos;

namespace ETL.BLL.Lectura;

public sealed class CsvExtractor(string ruta) : IExtractor
{
    public string Fuente => "encuestas-csv";

    public async IAsyncEnumerable<IReadOnlyDictionary<string, object?>> ExtraerAsync(
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        await using var flujo = new FileStream(ruta, FileMode.Open, FileAccess.Read, FileShare.Read,
            bufferSize: 65536, FileOptions.Asynchronous | FileOptions.SequentialScan);
        using var lector = FormatoCsv.AbrirTexto(flujo);
        using var csv = FormatoCsv.CrearLector(lector);

        if (!await csv.ReadAsync())
            throw new ErrorArchivoCsvException("El archivo no contiene encabezado.");
        var encabezados = FormatoCsv.LeerEncabezados(csv, ColumnasEncuesta.Valores);

        while (await csv.ReadAsync())
        {
            cancellationToken.ThrowIfCancellationRequested();
            var valores = csv.Parser.Record ?? [];
            if (valores.Length != encabezados.Length)
                throw new ErrorArchivoCsvException("Cantidad de columnas incorrecta.");

            yield return FormatoCsv.ObtenerCampos<object?>(encabezados, valores, valor => valor);
        }
    }
}
