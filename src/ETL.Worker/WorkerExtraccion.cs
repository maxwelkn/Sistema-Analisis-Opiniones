using System.Runtime.InteropServices;

namespace ETL.Worker;

internal sealed class WorkerExtraccion(
    ProcesoExtraccion proceso,
    ILogger<WorkerExtraccion> logger,
    IHostApplicationLifetime aplicacion) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        await Task.Yield();
        using var origen = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken, aplicacion.ApplicationStopping);
        var cancelacion = origen.Token;
        logger.LogInformation("Worker de extracción iniciado sobre {Runtime}.", RuntimeInformation.FrameworkDescription);
        try
        {
            await proceso.EjecutarAsync(cancelacion);
            Environment.ExitCode = 0;
        }
        catch (OperationCanceledException) when (cancelacion.IsCancellationRequested)
        {
            Environment.ExitCode = 130;
        }
        catch (Exception)
        {
            Environment.ExitCode = 1;
        }
        finally
        {
            aplicacion.StopApplication();
        }
    }
}
