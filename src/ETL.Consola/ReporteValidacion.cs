using System.Text.Json;
using ETL.Entities.Validacion;

namespace ETL.Consola;

internal static class ReporteValidacion
{
    public static async Task<string> GuardarAsync(
        ResultadoValidacion resultado, string directorio, CancellationToken cancellationToken)
    {
        Directory.CreateDirectory(directorio);
        var nombre = $"validacion-{DateTime.UtcNow:yyyyMMdd-HHmmss}-{Guid.NewGuid():N}.json";
        var ruta = Path.Combine(directorio, nombre);
        var rechazos = new[]
        {
            Detalles(resultado.Clientes.Archivo, resultado.Clientes.Rechazos),
            Detalles(resultado.Productos.Archivo, resultado.Productos.Rechazos),
            Detalles(resultado.Fuentes.Archivo, resultado.Fuentes.Rechazos),
            Detalles(resultado.Web.Archivo, resultado.Web.Rechazos),
            Detalles(resultado.Encuestas.Archivo, resultado.Encuestas.Rechazos),
            Detalles(resultado.Redes.Archivo, resultado.Redes.Rechazos)
        }.SelectMany(detalles => detalles).ToArray();
        var reporte = new
        {
            Tipo = "ValidacionSinPersistencia",
            FechaEjecucionUtc = DateTimeOffset.UtcNow,
            resultado.Completa,
            resultado.Procesados,
            resultado.Aptos,
            resultado.Rechazados,
            resultado.Omitidos,
            resultado.Archivos,
            Rechazos = rechazos
        };
        await using var destino = new FileStream(ruta, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        await JsonSerializer.SerializeAsync(destino, reporte,
            new JsonSerializerOptions { WriteIndented = true }, cancellationToken);
        return ruta;
    }

    public static string DirectorioPredeterminado()
    {
        var directorio = new DirectoryInfo(Environment.CurrentDirectory);
        while (directorio is not null)
        {
            if (File.Exists(Path.Combine(directorio.FullName, "SistemaAnalisisOpiniones.sln")))
                return Path.Combine(directorio.FullName, "reportes-locales");
            directorio = directorio.Parent;
        }
        return Path.Combine(Environment.CurrentDirectory, "reportes-locales");
    }

    private static IEnumerable<object> Detalles(string archivo, IReadOnlyList<RechazoRegistro> rechazos) =>
        rechazos.Select(rechazo => new
        {
            Archivo = archivo, rechazo.Registro, rechazo.Linea, rechazo.Motivos
        });
}
