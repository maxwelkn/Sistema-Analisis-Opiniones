using ETL.Consola;

using var cancelacion = new CancellationTokenSource();
Console.CancelKeyPress += (_, evento) =>
{
    evento.Cancel = true;
    cancelacion.Cancel();
};

return await AplicacionConsola.EjecutarAsync(args, Console.Out, Console.Error, cancelacion.Token);
