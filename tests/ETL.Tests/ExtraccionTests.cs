using System.Runtime.CompilerServices;
using System.Text;
using System.Text.Json;
using ETL.BLL.Lectura;
using ETL.DAL.Extraccion;
using ETL.Entities.Contratos;
using ETL.Worker;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace ETL.Tests;

public sealed class ExtraccionTests : IDisposable
{
    private readonly string directorio = Directory.CreateTempSubdirectory("etl-extraccion-").FullName;

    [Fact]
    public async Task CsvConservaCodigosAcentosComillasYSaltos()
    {
        var ruta = Path.Combine(directorio, "encuestas.csv");
        await File.WriteAllTextAsync(ruta,
            """
            IdOpinion,IdCliente,IdProducto,Fecha,Comentario,Clasificación,PuntajeSatisfacción,Fuente
            T0001,C007,P016,2026-01-01,"Opinión, con ""comillas""
            y salto",Positiva,5,EncuestaInterna
            """, new UTF8Encoding(true), TestContext.Current.CancellationToken);

        var filas = new List<IReadOnlyDictionary<string, object?>>();
        await foreach (var fila in new CsvExtractor(ruta).ExtraerAsync(TestContext.Current.CancellationToken))
            filas.Add(fila);

        var registro = Assert.Single(filas);
        Assert.Equal("T0001", registro["IdOpinion"]);
        Assert.Equal("C007", registro["IdCliente"]);
        Assert.Equal("P016", registro["IdProducto"]);
        Assert.Equal("Positiva", registro["Clasificación"]);
        var comentario = Assert.IsType<string>(registro["Comentario"]).ReplaceLineEndings("\n");
        Assert.Equal("Opinión, con \"comillas\"\ny salto", comentario);
    }

    [Theory]
    [InlineData("http://example.invalid/comentarios", true, null)]
    [InlineData("http://127.0.0.1/comentarios", false, null)]
    [InlineData("http://127.0.0.1/comentarios", true, "token-de-prueba")]
    [InlineData("https://usuario:clave@example.invalid/comentarios", false, null)]
    public void ApiRechazaConfiguracionesInseguras(string url, bool permitirHttp, string? token)
    {
        using var http = new HttpClient();
        Assert.Throws<ArgumentException>(() => new ApiExtractor(http, new Uri(url), token, permitirHttp));
    }

    [Fact]
    public void SqlRechazaCifradoOpcional()
    {
        Assert.Throws<ArgumentException>(() => new DatabaseExtractor(
            "Server=localhost;Database=Ejemplo;Integrated Security=True;Encrypt=Optional;"));
    }

    [Fact]
    public async Task PublicaTodosLosArchivosDeCadaEjecucion()
    {
        var token = TestContext.Current.CancellationToken;
        var proceso = CrearProceso(new ExtractorFalso("fuente-a", UnaFila), new ExtractorFalso("fuente-b", UnaFila));

        await Task.WhenAll(proceso.EjecutarAsync(token), proceso.EjecutarAsync(token));

        var ejecuciones = Directory.GetDirectories(directorio);
        Assert.Equal(2, ejecuciones.Length);
        foreach (var ejecucion in ejecuciones)
        {
            Assert.False(ejecucion.EndsWith(".partial", StringComparison.Ordinal));
            var archivos = Directory.GetFiles(ejecucion, "*.ndjson");
            Assert.Equal(2, archivos.Length);
            foreach (var archivo in archivos)
            {
                var linea = Assert.Single(await File.ReadAllLinesAsync(archivo, token));
                using var registro = JsonDocument.Parse(linea);
                Assert.Equal("X01", registro.RootElement.GetProperty("Id").GetString());
            }
        }
    }

    [Fact]
    public async Task CancelaFuentesHermanasYEliminaStagingParcialAnteError()
    {
        var enCurso = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var detenida = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var proceso = CrearProceso(new ExtractorFalso("lenta", Esperar), new ExtractorFalso("error", Fallar));

        await Assert.ThrowsAsync<InvalidDataException>(() => proceso.EjecutarAsync(TestContext.Current.CancellationToken)
            .WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken));

        Assert.True(detenida.Task.IsCompleted);
        Assert.Empty(Directory.EnumerateFileSystemEntries(directorio));

        async IAsyncEnumerable<IReadOnlyDictionary<string, object?>> Esperar(
            [EnumeratorCancellation] CancellationToken token)
        {
            try
            {
                yield return new Dictionary<string, object?> { ["Id"] = "X01" };
                enCurso.SetResult();
                await Task.Delay(Timeout.Infinite, token);
            }
            finally
            {
                detenida.SetResult();
            }
        }

        async IAsyncEnumerable<IReadOnlyDictionary<string, object?>> Fallar(
            [EnumeratorCancellation] CancellationToken token)
        {
            yield return new Dictionary<string, object?> { ["Id"] = "X01" };
            await enCurso.Task.WaitAsync(token);
            throw new InvalidDataException("Error simulado.");
        }
    }

    [Fact]
    public async Task CancelacionSolicitadaEliminaStagingParcial()
    {
        var enCurso = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        using var cancelacion = CancellationTokenSource.CreateLinkedTokenSource(TestContext.Current.CancellationToken);
        var proceso = CrearProceso(new ExtractorFalso("lenta", Esperar));

        var ejecucion = proceso.EjecutarAsync(cancelacion.Token);
        await enCurso.Task.WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken);
        await cancelacion.CancelAsync();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => ejecucion.WaitAsync(TimeSpan.FromSeconds(5), TestContext.Current.CancellationToken));
        Assert.Empty(Directory.EnumerateFileSystemEntries(directorio));

        async IAsyncEnumerable<IReadOnlyDictionary<string, object?>> Esperar(
            [EnumeratorCancellation] CancellationToken token)
        {
            yield return new Dictionary<string, object?> { ["Id"] = "X01" };
            enCurso.SetResult();
            await Task.Delay(Timeout.Infinite, token);
        }
    }

    private ProcesoExtraccion CrearProceso(params IExtractor[] extractores) =>
        new(extractores, directorio, NullLogger<ProcesoExtraccion>.Instance);

    private static async IAsyncEnumerable<IReadOnlyDictionary<string, object?>> UnaFila(
        [EnumeratorCancellation] CancellationToken token)
    {
        await Task.Yield();
        token.ThrowIfCancellationRequested();
        yield return new Dictionary<string, object?> { ["Id"] = "X01" };
    }

    public void Dispose() => Directory.Delete(directorio, recursive: true);

    private sealed class ExtractorFalso(
        string fuente, Func<CancellationToken, IAsyncEnumerable<IReadOnlyDictionary<string, object?>>> extraer) : IExtractor
    {
        public string Fuente => fuente;
        public IAsyncEnumerable<IReadOnlyDictionary<string, object?>> ExtraerAsync(CancellationToken cancellationToken) =>
            extraer(cancellationToken);
    }
}
