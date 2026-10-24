using ETL.BLL.Carga;
using ETL.Consola;
using ETL.Entities.Carga;
using Xunit;

namespace ETL.Tests;

public sealed class ServicioCargaTests
{
    [Fact]
    public async Task ConfirmaUnaTransaccionYUsaLasClavesDevueltasPorLaSesion()
    {
        using var csv = new ConjuntoCsv();
        var sesion = new SesionCargaFalsa();
        var fabrica = new FabricaSesionFalsa(sesion);
        var resultado = await new ServicioCarga(fabrica).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.Equal(EstadoCarga.Confirmada, resultado.Estado);
        Assert.Equal(6, resultado.Insertados);
        Assert.Equal(5, resultado.FuentesTecnicas.Insertadas);
        Assert.Equal(0, resultado.Pendientes);
        Assert.Equal(1, fabrica.Aperturas);
        Assert.True(sesion.Confirmada);
        Assert.True(sesion.Liberada);
        Assert.False(sesion.Revertida);
        Assert.All(sesion.Opiniones, opinion =>
        {
            Assert.Equal(101, opinion.IdCliente);
            Assert.Equal(201, opinion.IdProducto);
        });
    }

    [Fact]
    public async Task EstructuraIncompletaNoAbreSql()
    {
        using var csv = new ConjuntoCsv();
        File.Delete(Path.Combine(csv.Directorio, "products.csv"));
        var fabrica = new FabricaSesionFalsa(new());
        var resultado = await new ServicioCarga(fabrica).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.Equal(EstadoCarga.NoIniciada, resultado.Estado);
        Assert.Equal(0, fabrica.Aperturas);
        Assert.Equal(0, resultado.Insertados);
    }

    [Fact]
    public async Task ConflictoEnMaestroRechazaSusOpinionesSinReutilizarSuId()
    {
        using var csv = new ConjuntoCsv();
        var sesion = new SesionCargaFalsa { EstadoCliente = EstadoPersistencia.Conflicto };
        var resultado = await new ServicioCarga(new FabricaSesionFalsa(sesion)).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.Equal(EstadoCarga.Confirmada, resultado.Estado);
        Assert.Equal(4, resultado.Rechazados);
        Assert.Equal(2, resultado.Insertados);
        Assert.Empty(sesion.Opiniones);
        Assert.Equal(resultado.Procesados, resultado.Insertados + resultado.Omitidos + resultado.Rechazados);
    }

    [Fact]
    public async Task ConflictoDeFuenteTecnicaRechazaDependenciasSinContarlaComoCsv()
    {
        using var csv = new ConjuntoCsv();
        var sesion = new SesionCargaFalsa { EstadoTecnica = EstadoPersistencia.Conflicto };
        var resultado = await new ServicioCarga(new FabricaSesionFalsa(sesion)).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.Equal(5, resultado.FuentesTecnicas.Conflictos);
        Assert.Equal(3, resultado.Rechazados);
        Assert.Equal(6, resultado.Procesados);
        Assert.Empty(sesion.Opiniones);
    }

    [Fact]
    public async Task ReejecucionOmiteLosDatosYConservaFechaTecnicaPersistida()
    {
        using var csv = new ConjuntoCsv();
        var fecha = new DateTime(2025, 1, 2);
        var sesion = new SesionCargaFalsa
        {
            FechaExistente = fecha,
            EstadoCliente = EstadoPersistencia.Omitido,
            EstadoProducto = EstadoPersistencia.Omitido,
            EstadoFuente = EstadoPersistencia.Omitido,
            EstadoOpinion = EstadoPersistencia.Omitido,
            EstadoTecnica = EstadoPersistencia.Omitido
        };
        var resultado = await new ServicioCarga(new FabricaSesionFalsa(sesion)).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.Equal(0, resultado.Insertados);
        Assert.Equal(6, resultado.Omitidos);
        Assert.Equal(5, resultado.FuentesTecnicas.Omitidas);
        Assert.All(sesion.Fuentes.Where(fuente => fuente.IdExterno.StartsWith("ETL:", StringComparison.Ordinal)),
            fuente => Assert.Equal(fecha, fuente.FechaCarga));
    }

    [Fact]
    public async Task FalloTecnicoRevierteYSusInsercionesQuedanPendientes()
    {
        using var csv = new ConjuntoCsv();
        var sesion = new SesionCargaFalsa { FallarOpinion = true };
        var resultado = await new ServicioCarga(new FabricaSesionFalsa(sesion)).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.Equal(EstadoCarga.Revertida, resultado.Estado);
        Assert.Equal(0, resultado.Insertados);
        Assert.Equal(0, resultado.FuentesTecnicas.Insertadas);
        Assert.Equal(6, resultado.Pendientes);
        Assert.True(sesion.Revertida);
        Assert.True(sesion.Liberada);
        Assert.False(sesion.Confirmada);
    }

    [Fact]
    public async Task CancelacionRevierteConTokenIndependiente()
    {
        using var csv = new ConjuntoCsv();
        var sesion = new SesionCargaFalsa { CancelarOpinion = true };
        var resultado = await new ServicioCarga(new FabricaSesionFalsa(sesion)).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.True(resultado.Cancelada);
        Assert.Equal(EstadoCarga.Revertida, resultado.Estado);
        Assert.Equal(CancellationToken.None, sesion.TokenReversion);
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task NoAfirmaRollbackAnteConfirmacionOReversionNoVerificables(bool fallaCommit, bool fallaRollback)
    {
        using var csv = new ConjuntoCsv();
        var sesion = new SesionCargaFalsa
        {
            FallarConfirmacion = fallaCommit,
            FallarOpinion = !fallaCommit,
            FallarReversion = fallaRollback
        };
        var resultado = await new ServicioCarga(new FabricaSesionFalsa(sesion)).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.Equal(EstadoCarga.Indeterminada, resultado.Estado);
        Assert.Equal(0, resultado.Insertados);
        Assert.NotNull(resultado.Error);
    }

    [Fact]
    public async Task FalloDeAperturaNoDeclaraUnaTransaccionRevertida()
    {
        using var csv = new ConjuntoCsv();
        var fabrica = new FabricaSesionFalsa(new()) { FallarApertura = true };
        var resultado = await new ServicioCarga(fabrica).CargarAsync(
            csv.Validar(TestContext.Current.CancellationToken), TestContext.Current.CancellationToken);
        Assert.Equal(EstadoCarga.NoIniciada, resultado.Estado);
        Assert.Equal(0, resultado.Insertados);
    }

    [Fact]
    public async Task ErrorDeReporteImpideAbrirLaSesionSql()
    {
        using var csv = new ConjuntoCsv();
        var fabrica = new FabricaSesionFalsa(new());
        using var salida = new StringWriter();
        using var errores = new StringWriter();
        var codigo = await AplicacionConsola.EjecutarAsync(
            ["--cargar", csv.Directorio, "--reportes", Path.Combine(csv.Directorio, "clients.csv")],
            salida, errores, TestContext.Current.CancellationToken, fabrica);
        Assert.Equal(1, codigo);
        Assert.Equal(0, fabrica.Aperturas);
    }

    [Fact]
    public async Task CargaDesdeConsolaPublicaSuEstadoYReporteSeparadosDeValidacion()
    {
        using var csv = new ConjuntoCsv();
        using var salida = new StringWriter();
        using var errores = new StringWriter();
        var reportes = Path.Combine(csv.Directorio, "reportes-locales");
        var codigo = await AplicacionConsola.EjecutarAsync(
            ["--cargar", csv.Directorio, "--reportes", reportes], salida, errores,
            TestContext.Current.CancellationToken, new FabricaSesionFalsa(new()));
        Assert.Equal(0, codigo);
        Assert.Contains("Estado de carga: Confirmada", salida.ToString());
        var reporte = File.ReadAllText(Assert.Single(Directory.GetFiles(reportes)));
        Assert.Contains("CargaTransaccional", reporte);
        Assert.Contains("Confirmada", reporte);
        Assert.DoesNotContain("prueba@example.test", reporte);
    }
}
