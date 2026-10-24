using System.Text.Json;
using ETL.Consola;
using Xunit;

namespace ETL.Tests;

public sealed class ConsolaTests
{
    [Fact]
    public async Task ValidacionCorrectaGeneraReporteSinContenidoPersonal()
    {
        using var datos = new ConjuntoCsv();
        var reportes = Path.Combine(datos.Directorio, "reportes-locales");
        using var salida = new StringWriter();
        using var errores = new StringWriter();
        var codigo = await AplicacionConsola.EjecutarAsync(
            ["--validar", datos.Directorio, "--reportes", reportes], salida, errores, TestContext.Current.CancellationToken);
        Assert.Equal(0, codigo);
        Assert.Equal(string.Empty, errores.ToString());
        Assert.Contains("TOTAL", salida.ToString());
        var contenido = File.ReadAllText(Assert.Single(Directory.GetFiles(reportes)));
        using var json = JsonDocument.Parse(contenido);
        Assert.Equal(6, json.RootElement.GetProperty("Aptos").GetInt32());
        Assert.True(json.RootElement.GetProperty("Completa").GetBoolean());
        Assert.DoesNotContain("prueba@example.test", contenido);
        Assert.DoesNotContain("Comentario web", contenido);
    }

    [Fact]
    public async Task RechazosDevuelvenCodigoDosSinConfundirseConFalloTecnico()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "IdCliente,Nombre,Email\n1,,\n");
        using var salida = new StringWriter();
        using var errores = new StringWriter();
        var codigo = await AplicacionConsola.EjecutarAsync(
            ["--validar", datos.Directorio, "--reportes", Path.Combine(datos.Directorio, "reportes-locales")], salida, errores, TestContext.Current.CancellationToken);
        Assert.Equal(2, codigo);
    }

    [Fact]
    public async Task ArchivoAusenteDevuelveCodigoUnoYReporteIncompleto()
    {
        using var datos = new ConjuntoCsv();
        File.Delete(Path.Combine(datos.Directorio, "clients.csv"));
        using var salida = new StringWriter();
        using var errores = new StringWriter();
        var codigo = await AplicacionConsola.EjecutarAsync(
            ["--validar", datos.Directorio, "--reportes", Path.Combine(datos.Directorio, "reportes-locales")], salida, errores, TestContext.Current.CancellationToken);
        Assert.Equal(1, codigo);
        Assert.Contains("incompleta", errores.ToString());
    }

    [Fact]
    public async Task ReporteSinPermisoDeEscrituraNoSePresentaComoExito()
    {
        using var datos = new ConjuntoCsv();
        using var salida = new StringWriter();
        using var errores = new StringWriter();
        var codigo = await AplicacionConsola.EjecutarAsync(
            ["--validar", datos.Directorio, "--reportes", Path.Combine(datos.Directorio, "clients.csv")], salida, errores, TestContext.Current.CancellationToken);
        Assert.Equal(1, codigo);
        Assert.Contains("reporte", errores.ToString());
    }

    [Theory]
    [InlineData("--desconocido")]
    [InlineData("--validar")]
    public async Task ArgumentosIncompletosNoEjecutanLaValidacion(string argumento)
    {
        using var salida = new StringWriter();
        using var errores = new StringWriter();
        Assert.Equal(1, await AplicacionConsola.EjecutarAsync([argumento], salida, errores, TestContext.Current.CancellationToken));
    }
}
