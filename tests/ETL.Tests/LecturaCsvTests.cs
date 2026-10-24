using System.Text;
using Xunit;

namespace ETL.Tests;

public sealed class LecturaCsvTests
{
    [Fact]
    public void LeeLosSeisFormatosConservandoAcentos()
    {
        using var datos = new ConjuntoCsv();
        var resultado = datos.Validar(TestContext.Current.CancellationToken);
        Assert.True(resultado.Completa);
        Assert.Equal(6, resultado.Procesados);
        Assert.Equal(6, resultado.Aptos);
        Assert.Equal(0, resultado.Rechazados);
        Assert.Equal("Pruebas", Assert.Single(resultado.Productos.Aptos).Datos.Categoria);
    }

    [Fact]
    public void AsociaColumnasPorNombreAunqueCambienDeOrden()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "Email,Nombre,IdCliente\nprueba@example.test,Cliente,1\n");
        var cliente = Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Clientes.Aptos).Datos;
        Assert.Equal("1", cliente.IdExterno);
        Assert.Equal("Cliente", cliente.Nombre);
    }

    [Theory]
    [InlineData("")]
    [InlineData("IdCliente,Nombre\n")]
    [InlineData("IdCliente,Nombre,Nombre\n")]
    [InlineData("IdCliente,Nombre,Email,Otra\n")]
    [InlineData("idcliente,Nombre,Email\n")]
    public void EncabezadoIncorrectoImpideValidarElArchivo(string contenido)
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", contenido);
        var resultado = datos.Validar(TestContext.Current.CancellationToken);
        Assert.False(resultado.Completa);
        Assert.NotNull(resultado.Clientes.ErrorEstructura);
        Assert.Empty(resultado.Clientes.Aptos);
        Assert.Empty(resultado.Web.Aptos);
    }

    [Fact]
    public void RechazaFilasConColumnasDistintasSinPerderLaSiguiente()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "IdCliente,Nombre,Email\n2,Cliente\n1,Cliente,prueba@example.test\n");
        var archivo = datos.Validar(TestContext.Current.CancellationToken).Clientes;
        Assert.Equal(2, archivo.Resumen.Procesados);
        Assert.Single(archivo.Rechazos);
        Assert.Single(archivo.Aptos);
    }

    [Fact]
    public void ConservaComasComillasSaltosDeLineaYEspaciosDelComentario()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("web_reviews.csv", "IdReview,IdCliente,IdProducto,Fecha,Comentario,Rating\nW1,C001,P001,2025-04-10,\"  Llegó, dijo \"\"bien\"\"\nsegunda línea  \",5\nW2,C001,P001,2025-04-10,Otra,4\n");
        var archivo = datos.Validar(TestContext.Current.CancellationToken).Web;
        Assert.Equal("  Llegó, dijo \"bien\"\nsegunda línea  ", archivo.Aptos[0].Datos.Comentario);
        Assert.Equal(2, archivo.Aptos[0].Linea);
        Assert.Equal(4, archivo.Aptos[1].Linea);
        Assert.Equal(2, archivo.Aptos[1].Registro);
    }

    [Fact]
    public void UnaLineaVaciaEsUnRechazoContabilizado()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "IdCliente,Nombre,Email\n\n1,Cliente,\n");
        var archivo = datos.Validar(TestContext.Current.CancellationToken).Clientes;
        Assert.Single(archivo.Rechazos);
        Assert.Single(archivo.Aptos);
        Assert.Equal(2, archivo.Resumen.Procesados);
    }

    [Fact]
    public void ComillasSinCerrarProducenFalloDeArchivoSinDatosCrudos()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "IdCliente,Nombre,Email\n1,\"dato privado sin cerrar,privado@example.test\n");
        var resultado = datos.Validar(TestContext.Current.CancellationToken).Clientes;
        Assert.NotNull(resultado.ErrorEstructura);
        Assert.DoesNotContain("privado", resultado.ErrorEstructura);
        Assert.Empty(resultado.Aptos);
    }

    [Fact]
    public void RechazaUtf8Invalido()
    {
        using var datos = new ConjuntoCsv();
        File.WriteAllBytes(Path.Combine(datos.Directorio, "clients.csv"), [0xff, 0xff, 0xff]);
        Assert.Contains("UTF-8", datos.Validar(TestContext.Current.CancellationToken).Clientes.ErrorEstructura!);
    }

    [Fact]
    public void AceptaBomUtf8SinAlterarElPrimerEncabezado()
    {
        using var datos = new ConjuntoCsv();
        File.WriteAllText(Path.Combine(datos.Directorio, "clients.csv"),
            "IdCliente,Nombre,Email\n1,Cliente,\n", new UTF8Encoding(true));
        Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Clientes.Aptos);
    }

    [Fact]
    public void ArchivoAusenteProduceValidacionIncompleta()
    {
        using var datos = new ConjuntoCsv();
        File.Delete(Path.Combine(datos.Directorio, "products.csv"));
        var resultado = datos.Validar(TestContext.Current.CancellationToken);
        Assert.False(resultado.Completa);
        Assert.NotNull(resultado.Productos.ErrorEstructura);
        Assert.Empty(resultado.Encuestas.Aptos);
    }

    [Fact]
    public void RespetaLaCancelacion()
    {
        using var datos = new ConjuntoCsv();
        using var cancelacion = new CancellationTokenSource();
        cancelacion.Cancel();
        Assert.Throws<OperationCanceledException>(() => datos.Validar(cancelacion.Token));
    }
}
