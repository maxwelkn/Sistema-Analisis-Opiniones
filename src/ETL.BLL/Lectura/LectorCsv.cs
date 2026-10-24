using System.Globalization;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;
using ETL.Entities.Validacion;

namespace ETL.BLL.Lectura;

internal sealed class LectorCsv
{
    public DocumentoCsv Leer(
        string ruta, IReadOnlyList<string> columnas, CancellationToken cancellationToken)
    {
        var configuracion = new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            Delimiter = ",",
            IgnoreBlankLines = false,
            TrimOptions = TrimOptions.None,
            ExceptionMessagesContainRawData = false
        };

        using var lector = new StreamReader(ruta, new UTF8Encoding(false, true), false);
        if (lector.Peek() == '\uFEFF')
            lector.Read();
        using var csv = new CsvReader(lector, configuracion);
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!csv.Read())
                throw new ErrorArchivoCsvException("El archivo no contiene encabezado.");
            csv.ReadHeader();
            var encabezados = csv.HeaderRecord ?? [];
            if (encabezados.Length != columnas.Count ||
                encabezados.Distinct(StringComparer.Ordinal).Count() != encabezados.Length ||
                !encabezados.ToHashSet(StringComparer.Ordinal).SetEquals(columnas))
                throw new ErrorArchivoCsvException("Encabezados faltantes, duplicados o no esperados.");

            var filas = new List<FilaCsv>();
            var rechazos = new List<RechazoRegistro>();
            long registro = 0;
            while (true)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var linea = csv.Parser.RawRow + 1L;
                if (!csv.Read())
                    break;
                registro++;
                var valores = csv.Parser.Record ?? [];
                if (valores.Length != encabezados.Length)
                {
                    rechazos.Add(new(registro, linea, ["Cantidad de columnas incorrecta."]));
                    continue;
                }
                var campos = encabezados.Select((columna, indice) =>
                    KeyValuePair.Create(columna, valores[indice])).ToDictionary(StringComparer.Ordinal);
                filas.Add(new(registro, linea, campos));
            }
            return new(filas, rechazos);
        }
        catch (CsvHelperException)
        {
            throw new ErrorArchivoCsvException("CSV mal formado; no es seguro continuar este archivo.");
        }
        catch (DecoderFallbackException)
        {
            throw new ErrorArchivoCsvException("El archivo no contiene UTF-8 valido.");
        }
    }
}
