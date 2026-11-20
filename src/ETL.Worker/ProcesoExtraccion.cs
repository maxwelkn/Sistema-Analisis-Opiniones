using System.Diagnostics;
using System.Text;
using System.Text.Json;
using ETL.Entities.Contratos;

namespace ETL.Worker;

public sealed class ProcesoExtraccion(
    IEnumerable<IExtractor> extractores, string directorio, ILogger<ProcesoExtraccion> logger)
{
    public async Task EjecutarAsync(CancellationToken cancellationToken)
    {
        var id = $"extraccion-{Guid.NewGuid():N}";
        var temporal = Path.Combine(directorio, $"{id}.partial");
        var destino = Path.Combine(directorio, id);
        var reloj = Stopwatch.StartNew();
        logger.LogInformation("Extracción {Ejecucion} en curso.", id);

        try
        {
            cancellationToken.ThrowIfCancellationRequested();
            Directory.CreateDirectory(temporal);
            using var cancelacion = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            var tareas = extractores.Select(extractor => ExtraerAsync(extractor, temporal, cancelacion)).ToArray();
            var conteos = await Task.WhenAll(tareas);
            cancellationToken.ThrowIfCancellationRequested();
            Directory.Move(temporal, destino);
            logger.LogInformation("Extracción {Ejecucion} completa. Total={Filas} DuraciónMs={DuracionMs}.",
                id, conteos.Sum(), reloj.ElapsedMilliseconds);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            EliminarTemporal(temporal, id);
            logger.LogWarning("Extracción {Ejecucion} cancelada. DuraciónMs={DuracionMs}.",
                id, reloj.ElapsedMilliseconds);
            throw;
        }
        catch (Exception error)
        {
            EliminarTemporal(temporal, id);
            logger.LogError("Extracción {Ejecucion} fallida. Tipo={Tipo} DuraciónMs={DuracionMs}.",
                id, error.GetType().Name, reloj.ElapsedMilliseconds);
            throw;
        }
    }

    private async Task<long> ExtraerAsync(
        IExtractor extractor, string temporal, CancellationTokenSource cancelacion)
    {
        var reloj = Stopwatch.StartNew();
        var token = cancelacion.Token;
        logger.LogInformation("Fuente {Fuente} en curso.", extractor.Fuente);
        try
        {
            long filas = 0;
            await using (var flujo = new FileStream(Path.Combine(temporal, $"{extractor.Fuente}.ndjson"),
                FileMode.CreateNew, FileAccess.Write, FileShare.None, 65536, FileOptions.Asynchronous))
            await using (var escritor = new StreamWriter(flujo, new UTF8Encoding(false), 65536))
            {
                await foreach (var registro in extractor.ExtraerAsync(token).WithCancellation(token))
                {
                    var linea = JsonSerializer.Serialize(registro);
                    await escritor.WriteLineAsync(linea.AsMemory(), token);
                    filas++;
                }

                await escritor.FlushAsync(token);
            }

            logger.LogInformation("Fuente {Fuente} completa. Filas={Filas} DuraciónMs={DuracionMs}.",
                extractor.Fuente, filas, reloj.ElapsedMilliseconds);
            return filas;
        }
        catch (OperationCanceledException) when (token.IsCancellationRequested)
        {
            logger.LogWarning("Fuente {Fuente} cancelada. DuraciónMs={DuracionMs}.",
                extractor.Fuente, reloj.ElapsedMilliseconds);
            throw;
        }
        catch (Exception error)
        {
            var estadoHttp = (error as HttpRequestException)?.StatusCode;
            logger.LogError("Fuente {Fuente} fallida. Tipo={Tipo} Http={Http} DuraciónMs={DuracionMs}.",
                extractor.Fuente, error.GetType().Name, (int?)estadoHttp, reloj.ElapsedMilliseconds);
            await cancelacion.CancelAsync();
            throw;
        }
    }

    private void EliminarTemporal(string temporal, string id)
    {
        try
        {
            if (Directory.Exists(temporal))
                Directory.Delete(temporal, recursive: true);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning("No se pudo limpiar la carpeta parcial de {Ejecucion}.", id);
        }
    }
}
