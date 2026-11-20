using System.Text;
using CsvHelper;
using ETL.Entities.Validacion;

namespace ETL.BLL.Lectura;

internal sealed class LectorCsv
{
    public DocumentoCsv Leer(
        string ruta, IReadOnlyList<string> columnas, CancellationToken cancellationToken)
    {
        using var flujo = File.OpenRead(ruta);
        using var lector = FormatoCsv.AbrirTexto(flujo);
        using var csv = FormatoCsv.CrearLector(lector);
        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!csv.Read())
                throw new ErrorArchivoCsvException("El archivo no contiene encabezado.");
            var encabezados = FormatoCsv.LeerEncabezados(csv, columnas);

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
                var campos = FormatoCsv.ObtenerCampos(encabezados, valores, valor => valor);
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
