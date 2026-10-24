using System.Data;
using ETL.DAL;
using ETL.Entities;
using ETL.Entities.Carga;
using Microsoft.Data.SqlClient;
using Xunit;

namespace ETL.Tests;

public sealed class SesionSqlTests
{
    public static bool SqlDisponible =>
        !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ETL_SQL_CONNECTION"));

    private static FabricaSesionSql Fabrica() =>
        new(Environment.GetEnvironmentVariable("ETL_SQL_CONNECTION")!);

    [Fact(Skip = "Requiere ETL_SQL_CONNECTION y una BD preparada.", SkipUnless = nameof(SqlDisponible))]
    public async Task SqlDistingueInsercionDuplicadoYConflictoSinSobrescribir()
    {
        var id = "PRUEBA-" + Guid.NewGuid().ToString("N");
        await using (var sesion = await Fabrica().AbrirAsync(TestContext.Current.CancellationToken))
        {
            var cliente = new Cliente(id, "Nombre inicial", null);
            var primero = await sesion.CargarClienteAsync(cliente, TestContext.Current.CancellationToken);
            var duplicado = await sesion.CargarClienteAsync(cliente, TestContext.Current.CancellationToken);
            var conflicto = await sesion.CargarClienteAsync(cliente with { Nombre = "Nombre distinto" }, TestContext.Current.CancellationToken);
            Assert.Equal(EstadoPersistencia.Insertado, primero.Estado);
            Assert.Equal(EstadoPersistencia.Omitido, duplicado.Estado);
            Assert.Equal(EstadoPersistencia.Conflicto, conflicto.Estado);
            Assert.Equal(primero.Id, duplicado.Id);
            var original = await sesion.CargarClienteAsync(cliente, TestContext.Current.CancellationToken);
            Assert.Equal(EstadoPersistencia.Omitido, original.Estado);
            await sesion.RevertirAsync(TestContext.Current.CancellationToken);
        }
        Assert.Equal(0, await ContarAsync(id, TestContext.Current.CancellationToken));
    }

    [Fact(Skip = "Requiere ETL_SQL_CONNECTION y una BD preparada.", SkipUnless = nameof(SqlDisponible))]
    public async Task SqlRelacionaLosCuatroTiposYRecuperaMetadatosDeFuente()
    {
        var id = "PRUEBA-" + Guid.NewGuid().ToString("N");
        var fecha = new DateTime(2025, 1, 1);
        await using (var sesion = await Fabrica().AbrirAsync(TestContext.Current.CancellationToken))
        {
            Assert.Null(await sesion.ObtenerFuenteAsync(id, TestContext.Current.CancellationToken));
            var cliente = await sesion.CargarClienteAsync(new(id, "Prueba", null), TestContext.Current.CancellationToken);
            var producto = await sesion.CargarProductoAsync(new(id, "Prueba", "Categoria"), TestContext.Current.CancellationToken);
            var fuente = await sesion.CargarFuenteAsync(new(id, "Web", fecha), TestContext.Current.CancellationToken);
            var metadato = await sesion.ObtenerFuenteAsync(id, TestContext.Current.CancellationToken);
            Assert.Equal(fecha, metadato!.FechaCarga);
            Assert.Equal("Web", metadato.TipoFuente);
            var opinion = new Opinion(id, "Web", cliente.Id, producto.Id, fuente.Id,
                fecha, "Comentario de prueba", null, 5, "C001", "P001");
            var primera = await sesion.CargarOpinionAsync(opinion, TestContext.Current.CancellationToken);
            var repetida = await sesion.CargarOpinionAsync(opinion, TestContext.Current.CancellationToken);
            Assert.Equal(EstadoPersistencia.Insertado, primera.Estado);
            Assert.Equal(EstadoPersistencia.Omitido, repetida.Estado);
            Assert.Equal(primera.Id, repetida.Id);
            Assert.True(primera.Id > 0);
            await sesion.RevertirAsync(TestContext.Current.CancellationToken);
        }
        Assert.Equal(0, await ContarAsync(id, TestContext.Current.CancellationToken));
    }

    [Fact(Skip = "Requiere ETL_SQL_CONNECTION y una BD preparada.", SkipUnless = nameof(SqlDisponible))]
    public async Task DisposeSinCommitRevierteLaInsercionReal()
    {
        var id = "PRUEBA-" + Guid.NewGuid().ToString("N");
        await using (var sesion = await Fabrica().AbrirAsync(TestContext.Current.CancellationToken))
            await sesion.CargarClienteAsync(new(id, "Prueba", null), TestContext.Current.CancellationToken);
        Assert.Equal(0, await ContarAsync(id, TestContext.Current.CancellationToken));
    }

    [Fact(Skip = "Requiere ETL_SQL_CONNECTION y una BD preparada.", SkipUnless = nameof(SqlDisponible))]
    public async Task ErrorFkRealNoConservaLosMaestrosInsertados()
    {
        var id = "PRUEBA-" + Guid.NewGuid().ToString("N");
        await using (var sesion = await Fabrica().AbrirAsync(TestContext.Current.CancellationToken))
        {
            var producto = await sesion.CargarProductoAsync(new(id, "Prueba", "Categoria"), TestContext.Current.CancellationToken);
            var fuente = await sesion.CargarFuenteAsync(new(id, "Web", new(2025, 1, 1)), TestContext.Current.CancellationToken);
            var opinion = new Opinion(id, "Web", -1, producto.Id, fuente.Id,
                new(2025, 1, 1), "Prueba de FK", null, null, "C-no-existe", "P-prueba");
            var error = await Assert.ThrowsAsync<ErrorPersistenciaException>(() =>
                sesion.CargarOpinionAsync(opinion, TestContext.Current.CancellationToken));
            Assert.Equal(547, Assert.IsType<SqlException>(error.InnerException).Number);
            await sesion.RevertirAsync(TestContext.Current.CancellationToken);
        }
        Assert.Equal(0, await ContarAsync(id, TestContext.Current.CancellationToken));
    }

    [Fact(Skip = "Requiere ETL_SQL_CONNECTION y una BD preparada.", SkipUnless = nameof(SqlDisponible))]
    public async Task SesionCerradaNoPermiteNuevasCargas()
    {
        await using var sesion = await Fabrica().AbrirAsync(TestContext.Current.CancellationToken);
        await sesion.RevertirAsync(TestContext.Current.CancellationToken);
        await Assert.ThrowsAsync<InvalidOperationException>(() => sesion.CargarClienteAsync(
            new("PRUEBA", "Prueba", null), TestContext.Current.CancellationToken));
    }

    [Fact(Skip = "Requiere ETL_SQL_CONNECTION y una BD preparada.", SkipUnless = nameof(SqlDisponible))]
    public async Task ParametrosLargosSeRechazanAntesDeQueSqlLosTrunque()
    {
        var id = "PRUEBA-" + Guid.NewGuid().ToString("N");
        await using (var sesion = await Fabrica().AbrirAsync(TestContext.Current.CancellationToken))
            await Assert.ThrowsAsync<ErrorPersistenciaException>(() => sesion.CargarClienteAsync(
                new(id, new string('A', 121), null), TestContext.Current.CancellationToken));
        Assert.Equal(0, await ContarAsync(id, TestContext.Current.CancellationToken));
    }

    [Fact]
    public void NoSePermiteUnaConexionSinBaseExplicita()
    {
        var error = Assert.Throws<ErrorPersistenciaException>(() => new FabricaSesionSql("Server=.;Integrated Security=True;"));
        Assert.Equal("Configuracion SQL no valida.", error.Message);
    }

    private static async Task<long> ContarAsync(string idExterno, CancellationToken cancellationToken)
    {
        await using var conexion = new SqlConnection(Environment.GetEnvironmentVariable("ETL_SQL_CONNECTION"));
        await conexion.OpenAsync(cancellationToken);
        using var comando = new SqlCommand("SELECT (SELECT COUNT_BIG(*) FROM dbo.Clientes WHERE IdExterno=@Id) + (SELECT COUNT_BIG(*) FROM dbo.Productos WHERE IdExterno=@Id) + (SELECT COUNT_BIG(*) FROM dbo.FuenteDatos WHERE IdExterno=@Id) + (SELECT COUNT_BIG(*) FROM dbo.Opiniones WHERE IdExterno=@Id);", conexion);
        comando.Parameters.Add("@Id", SqlDbType.NVarChar, 100).Value = idExterno;
        return (long)(await comando.ExecuteScalarAsync(cancellationToken))!;
    }
}
