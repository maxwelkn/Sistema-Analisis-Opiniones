using System.Text.Json;
using System.Text.Json.Serialization;
using ETL.Entities.Carga;

namespace ETL.Consola;

internal sealed class ReporteCarga : IAsyncDisposable
{
    private readonly FileStream destino;
    public string Ruta { get; }

    public ReporteCarga(string directorio)
    {
        Directory.CreateDirectory(directorio);
        Ruta = Path.Combine(directorio, $"carga-{DateTime.UtcNow:yyyyMMdd-HHmmss}-{Guid.NewGuid():N}.json");
        destino = new(Ruta, FileMode.CreateNew, FileAccess.Write, FileShare.None);
    }

    public async Task GuardarAsync(ResultadoCarga resultado)
    {
        var opciones = new JsonSerializerOptions { WriteIndented = true };
        opciones.Converters.Add(new JsonStringEnumConverter());
        await JsonSerializer.SerializeAsync(destino, new
        {
            Tipo = "CargaTransaccional",
            FechaEjecucionUtc = DateTimeOffset.UtcNow,
            resultado.Estado,
            resultado.Procesados,
            resultado.Insertados,
            resultado.Omitidos,
            resultado.Rechazados,
            resultado.Pendientes,
            resultado.Archivos,
            resultado.FuentesTecnicas,
            resultado.Rechazos,
            resultado.Error,
            resultado.Cancelada
        }, opciones, CancellationToken.None);
        await destino.FlushAsync(CancellationToken.None);
    }

    public ValueTask DisposeAsync() => destino.DisposeAsync();
}
