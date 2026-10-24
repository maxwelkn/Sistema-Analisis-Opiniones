using System.Globalization;
using Xunit;

namespace ETL.Tests;

public sealed class ValidacionReglasTests
{
    [Fact]
    public void NormalizaReferenciasPeroConservaCodigosOriginales()
    {
        using var datos = new ConjuntoCsv();
        var opinion = Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Web.Aptos).Datos;
        Assert.Equal("1", opinion.IdClienteExterno);
        Assert.Equal("1", opinion.IdProductoExterno);
        Assert.Equal("C001", opinion.IdClienteOrigen);
        Assert.Equal("P001", opinion.IdProductoOrigen);
        Assert.Null(opinion.Clasificacion);
        Assert.Equal((byte)5, opinion.PuntajeSatisfaccion);
    }

    [Fact]
    public void DosReferenciasAusentesSonUnaFilaRechazadaConDosMotivos()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("surveys_part1.csv", "IdOpinion,IdCliente,IdProducto,Fecha,Comentario,Clasificación,PuntajeSatisfacción,Fuente\n1,99,88,2025-04-10,Comentario,Neutra,3,EncuestaInterna\n");
        var rechazo = Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Encuestas.Rechazos);
        Assert.Equal(2, rechazo.Motivos.Count);
    }

    [Theory]
    [InlineData("", true)]
    [InlineData("C999", false)]
    [InlineData("C000", false)]
    [InlineData("999", false)]
    public void ClienteSocialVacioEsDistintoDeReferenciaInformadaInvalida(string cliente, bool valido)
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("social_comments.csv", $"IdComment,IdCliente,IdProducto,Fuente,Fecha,Comentario\nT1,{cliente},P001,Twitter,2025-04-10,Comentario\n");
        var archivo = datos.Validar(TestContext.Current.CancellationToken).Redes;
        Assert.Equal(valido ? 1 : 0, archivo.Aptos.Count);
        if (valido)
        {
            Assert.Null(archivo.Aptos[0].Datos.IdClienteExterno);
            Assert.Null(archivo.Aptos[0].Datos.PuntajeSatisfaccion);
        }
    }

    [Theory]
    [InlineData("W1,C001,,2025-04-10,Comentario,4")]
    [InlineData("W1,C001,P001,2025-02-30,Comentario,4")]
    [InlineData("W1,C001,P001,10/04/2025,Comentario,4")]
    [InlineData("W1,C001,P001,2025-04-10,   ,4")]
    [InlineData("W1,C001,P001,2025-04-10,Comentario,0")]
    [InlineData("W1,C001,P001,2025-04-10,Comentario,6")]
    [InlineData("W1,C001,P001,2025-04-10,Comentario,3.5")]
    [InlineData("W1,C001,P001,2025-04-10,Comentario,texto")]
    [InlineData("W1,C001,P001,2025-04-10,Comentario,")]
    [InlineData("W1,C-1,P001,2025-04-10,Comentario,4")]
    public void RechazaCamposWebInvalidos(string fila)
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("web_reviews.csv", "IdReview,IdCliente,IdProducto,Fecha,Comentario,Rating\n" + fila + "\n");
        var archivo = datos.Validar(TestContext.Current.CancellationToken).Web;
        Assert.Single(archivo.Rechazos);
        Assert.Empty(archivo.Aptos);
    }

    [Theory]
    [InlineData("1,Cliente,correo-invalido")]
    [InlineData("0,Cliente,correo@example.test")]
    [InlineData("-1,Cliente,correo@example.test")]
    [InlineData("abc,Cliente,correo@example.test")]
    [InlineData("2147483648,Cliente,correo@example.test")]
    [InlineData("1, ,correo@example.test")]
    public void RechazaClientesInvalidos(string fila)
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "IdCliente,Nombre,Email\n" + fila + "\n");
        Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Clientes.Rechazos);
    }

    [Fact]
    public void NoTruncaNombresQueExcedenElDestino()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "IdCliente,Nombre,Email\n1," + new string('A', 121) + ",\n");
        Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Clientes.Rechazos);
    }

    [Fact]
    public void DuplicadosIdenticosSeOmitenYConflictosSeRechazanSinSobrescribir()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "IdCliente,Nombre,Email\n1,Primero,\n001,Primero,\n1,Cambio,\n");
        var resultado = datos.Validar(TestContext.Current.CancellationToken);
        var archivo = resultado.Clientes;
        Assert.Equal(3, archivo.Resumen.Procesados);
        Assert.Equal(1, archivo.Omitidos);
        Assert.Single(archivo.Rechazos);
        Assert.Equal("Primero", Assert.Single(archivo.Aptos).Datos.Nombre);
        Assert.Equal(resultado.Procesados, resultado.Aptos + resultado.Omitidos + resultado.Rechazados);
    }

    [Fact]
    public void UnaFilaInvalidaNoReservaLaClaveParaLaFilaCorregida()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("clients.csv", "IdCliente,Nombre,Email\n1,,\n1,Corregido,\n");
        var resultado = datos.Validar(TestContext.Current.CancellationToken).Clientes;
        Assert.Single(resultado.Aptos);
        Assert.Single(resultado.Rechazos);
    }

    [Theory]
    [InlineData("Desconocida", "4", "EncuestaInterna")]
    [InlineData("Positiva", "9", "EncuestaInterna")]
    [InlineData("Positiva", "4", "FuenteInventada")]
    public void RechazaClasificacionPuntajeYFuenteDeEncuestaInvalidos(string clase, string puntaje, string fuente)
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("surveys_part1.csv", $"IdOpinion,IdCliente,IdProducto,Fecha,Comentario,Clasificación,PuntajeSatisfacción,Fuente\n1,1,1,2025-04-10,Comentario,{clase},{puntaje},{fuente}\n");
        Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Encuestas.Rechazos);
    }

    [Fact]
    public void FechasNoDependenDeLaCulturaDelEquipo()
    {
        using var datos = new ConjuntoCsv();
        var anterior = CultureInfo.CurrentCulture;
        try
        {
            CultureInfo.CurrentCulture = new CultureInfo("es-DO");
            Assert.Equal(new DateTime(2025, 4, 10), datos.Validar(TestContext.Current.CancellationToken).Web.Aptos[0].Datos.Fecha);
        }
        finally
        {
            CultureInfo.CurrentCulture = anterior;
        }
    }

    [Fact]
    public void ClienteVacioSeAdmiteEnTodosLosCanalesSegunElModeloOpcional()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("web_reviews.csv", "IdReview,IdCliente,IdProducto,Fecha,Comentario,Rating\nW1,,P001,2025-04-10,Comentario,4\n");
        datos.Escribir("surveys_part1.csv", "IdOpinion,IdCliente,IdProducto,Fecha,Comentario,Clasificación,PuntajeSatisfacción,Fuente\n1,,1,2025-04-10,Comentario,Neutra,3,EncuestaInterna\n");
        var resultado = datos.Validar(TestContext.Current.CancellationToken);
        Assert.Null(Assert.Single(resultado.Web.Aptos).Datos.IdClienteExterno);
        Assert.Null(Assert.Single(resultado.Encuestas.Aptos).Datos.IdClienteExterno);
    }

    [Fact]
    public void NoConfundeIdentificadoresDeCanalesDiferentes()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("web_reviews.csv", "IdReview,IdCliente,IdProducto,Fecha,Comentario,Rating\n1,C001,P001,2025-04-10,Comentario,4\n");
        var resultado = datos.Validar(TestContext.Current.CancellationToken);
        Assert.Single(resultado.Web.Aptos);
        Assert.Single(resultado.Encuestas.Aptos);
        Assert.Equal(0, resultado.Omitidos);
    }

    [Fact]
    public void RechazaTipoDeFuenteYFechaInvalidosSinInventarValores()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("fuente_datos.csv", "IdFuente,TipoFuente,FechaCarga\nF001,Desconocida,fecha\n");
        var rechazo = Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Fuentes.Rechazos);
        Assert.True(rechazo.Motivos.Count >= 2);
    }

    [Fact]
    public void RechazaCategoriaVaciaYNoLaSustituye()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("products.csv", "IdProducto,Nombre,Categoría\n1,Producto,\n");
        Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Productos.Rechazos);
    }

    [Fact]
    public void RechazaFuenteSocialDesconocida()
    {
        using var datos = new ConjuntoCsv();
        datos.Escribir("social_comments.csv", "IdComment,IdCliente,IdProducto,Fuente,Fecha,Comentario\nT1,,P001,Inventada,2025-04-10,Comentario\n");
        Assert.Single(datos.Validar(TestContext.Current.CancellationToken).Redes.Rechazos);
    }

    [Fact]
    public void DuplicadosWebIdenticosNoSeCuentanComoDosAptos()
    {
        using var datos = new ConjuntoCsv();
        const string fila = "W1,C001,P001,2025-04-10,Comentario,4\n";
        datos.Escribir("web_reviews.csv", "IdReview,IdCliente,IdProducto,Fecha,Comentario,Rating\n" + fila + fila);
        var archivo = datos.Validar(TestContext.Current.CancellationToken).Web;
        Assert.Single(archivo.Aptos);
        Assert.Equal(1, archivo.Omitidos);
    }
}
