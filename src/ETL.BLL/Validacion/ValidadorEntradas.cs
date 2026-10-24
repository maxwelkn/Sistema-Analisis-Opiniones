using ETL.Entities;
using ETL.Entities.Validacion;

namespace ETL.BLL.Validacion;

internal sealed class ValidadorEntradas
{
    public (Cliente Datos, IReadOnlyList<string> Errores) Cliente(IReadOnlyDictionary<string, string> fila)
    {
        var campos = new CamposValidacion(fila);
        var id = campos.IdNumerico("IdCliente");
        var nombre = campos.Texto("Nombre", 120);
        var email = campos.Email();
        return (new(id ?? string.Empty, nombre, email), campos.Errores);
    }

    public (Producto Datos, IReadOnlyList<string> Errores) Producto(IReadOnlyDictionary<string, string> fila)
    {
        var campos = new CamposValidacion(fila);
        var id = campos.IdNumerico("IdProducto");
        var nombre = campos.Texto("Nombre", 150);
        var categoria = campos.Texto("Categoría", 100);
        return (new(id ?? string.Empty, nombre, categoria), campos.Errores);
    }

    public (FuenteDatos Datos, IReadOnlyList<string> Errores) Fuente(IReadOnlyDictionary<string, string> fila)
    {
        var campos = new CamposValidacion(fila);
        var id = campos.Texto("IdFuente", 100);
        var tipo = campos.Permitido("TipoFuente", 50, "Web", "CSV", "Red Social");
        var fecha = campos.Fecha("FechaCarga");
        return (new(id, tipo, fecha), campos.Errores);
    }

    public (OpinionEntrada Datos, IReadOnlyList<string> Errores) Opinion(
        IReadOnlyDictionary<string, string> fila, string canal,
        IReadOnlySet<string>? clientes, IReadOnlySet<string>? productos)
    {
        var campos = new CamposValidacion(fila);
        var encuesta = canal == "Encuesta";
        var id = encuesta ? campos.IdNumerico("IdOpinion") ?? string.Empty
            : campos.Texto(canal == "Web" ? "IdReview" : "IdComment", 50);
        var clienteOrigen = campos.Origen("IdCliente", obligatorio: false);
        var productoOrigen = campos.Origen("IdProducto", obligatorio: true);
        var cliente = campos.IdNumerico("IdCliente", encuesta ? null : 'C', obligatorio: false);
        var producto = campos.IdNumerico("IdProducto", encuesta ? null : 'P');
        var fecha = campos.Fecha("Fecha");
        var comentario = campos.Texto("Comentario", int.MaxValue, recortar: false);
        var fuente = canal switch
        {
            "Web" => "web_reviews",
            "Encuesta" => campos.Permitido("Fuente", 50, "EncuestaInterna"),
            _ => campos.Permitido("Fuente", 50, "Instagram", "Twitter", "Facebook")
        };
        var clasificacion = encuesta
            ? campos.Permitido("Clasificación", 10, "Positiva", "Negativa", "Neutra") : null;
        byte? puntaje = canal switch
        {
            "Web" => campos.Puntaje("Rating"),
            "Encuesta" => campos.Puntaje("PuntajeSatisfacción"),
            _ => null
        };
        if (cliente is not null && clientes is null)
            campos.Errores.Add("IdCliente: catalogo no disponible por error de estructura.");
        else if (cliente is not null && clientes is not null && !clientes.Contains(cliente))
            campos.Errores.Add("IdCliente: referencia ausente del catalogo valido.");
        if (productos is null)
            campos.Errores.Add("IdProducto: catalogo no disponible por error de estructura.");
        else if (producto is not null && !productos.Contains(producto))
            campos.Errores.Add("IdProducto: referencia ausente del catalogo valido.");

        return (new(id, canal, cliente, producto ?? string.Empty, fuente, fecha, comentario,
            clasificacion, puntaje, clienteOrigen, productoOrigen ?? string.Empty), campos.Errores);
    }
}
