using ETL.BLL.Lectura;
using ETL.DAL.Extraccion;
using ETL.Entities.Contratos;
using ETL.Worker;

Console.OutputEncoding = System.Text.Encoding.UTF8;

try
{
    var builder = Host.CreateApplicationBuilder(new HostApplicationBuilderSettings
    {
        Args = args,
        ContentRootPath = AppContext.BaseDirectory
    });
    var ajustes = AjustesExtraccion.Leer(builder.Configuration);

    builder.Services.AddSingleton<IExtractor>(new CsvExtractor(ajustes.EncuestasCsv));
    builder.Services.AddSingleton<IExtractor>(new DatabaseExtractor(ajustes.ConexionSql));
    builder.Services.AddHttpClient("Comentarios")
        .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler
        {
            AllowAutoRedirect = false,
            UseProxy = !ajustes.UrlApi.IsLoopback
        })
        .RemoveAllLoggers();
    builder.Services.AddSingleton<IExtractor>(servicios => new ApiExtractor(
        servicios.GetRequiredService<IHttpClientFactory>().CreateClient("Comentarios"),
        ajustes.UrlApi, ajustes.TokenApi, ajustes.PermitirHttpLocal));
    builder.Services.AddSingleton(servicios => new ProcesoExtraccion(
        servicios.GetServices<IExtractor>(),
        ajustes.DirectorioTemporal,
        servicios.GetRequiredService<ILogger<ProcesoExtraccion>>()));
    builder.Services.AddHostedService<WorkerExtraccion>();
    builder.Services.Configure<HostOptions>(opciones => opciones.ShutdownTimeout = TimeSpan.FromMinutes(2));

    await builder.Build().RunAsync();
    return Environment.ExitCode;
}
catch (Exception error) when (error is ArgumentException or FormatException or IOException or InvalidOperationException)
{
    Console.Error.WriteLine("No se pudo iniciar el Worker. Revisa las opciones, el cifrado SQL y la URL de la API.");
    return 1;
}
