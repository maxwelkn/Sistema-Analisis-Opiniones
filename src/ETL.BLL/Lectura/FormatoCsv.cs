using System.Globalization;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;

namespace ETL.BLL.Lectura;

internal static class FormatoCsv
{
    public static StreamReader AbrirTexto(Stream flujo) =>
        new(flujo, new UTF8Encoding(true, true), detectEncodingFromByteOrderMarks: false);

    public static CsvReader CrearLector(TextReader lector) =>
        new(lector, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            Delimiter = ",",
            IgnoreBlankLines = false,
            TrimOptions = TrimOptions.None,
            ExceptionMessagesContainRawData = false
        });

    public static string[] LeerEncabezados(CsvReader csv, IReadOnlyList<string> columnas)
    {
        csv.ReadHeader();
        var encabezados = csv.HeaderRecord ?? [];
        if (encabezados.Length != columnas.Count ||
            encabezados.Distinct(StringComparer.Ordinal).Count() != encabezados.Length ||
            !encabezados.ToHashSet(StringComparer.Ordinal).SetEquals(columnas))
            throw new ErrorArchivoCsvException("Encabezados faltantes, duplicados o no esperados.");

        return encabezados;
    }

    public static Dictionary<string, T> ObtenerCampos<T>(
        string[] encabezados, string[] valores, Func<string, T> convertir)
    {
        var campos = new Dictionary<string, T>(encabezados.Length, StringComparer.Ordinal);
        for (var indice = 0; indice < encabezados.Length; indice++)
            campos.Add(encabezados[indice], convertir(valores[indice]));
        return campos;
    }
}
