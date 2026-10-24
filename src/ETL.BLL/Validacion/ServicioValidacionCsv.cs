using System.Text;
using ETL.BLL.Lectura;
using ETL.Entities;
using ETL.Entities.Validacion;

namespace ETL.BLL.Validacion;

public sealed class ServicioValidacionCsv
{
    private readonly LectorCsv lector = new();
    private readonly ValidadorEntradas validador = new();

    public ResultadoValidacion Validar(string directorio, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(directorio);
        var clientes = ValidarArchivo(directorio, "clients.csv", ["IdCliente", "Nombre", "Email"],
            validador.Cliente, cliente => cliente.IdExterno, cancellationToken);
        var productos = ValidarArchivo(directorio, "products.csv", ["IdProducto", "Nombre", "Categoría"],
            validador.Producto, producto => producto.IdExterno, cancellationToken);
        var fuentes = ValidarArchivo(directorio, "fuente_datos.csv", ["IdFuente", "TipoFuente", "FechaCarga"],
            validador.Fuente, fuente => fuente.IdExterno, cancellationToken);
        var idsClientes = clientes.ErrorEstructura is null
            ? clientes.Aptos.Select(registro => registro.Datos.IdExterno).ToHashSet(StringComparer.Ordinal) : null;
        var idsProductos = productos.ErrorEstructura is null
            ? productos.Aptos.Select(registro => registro.Datos.IdExterno).ToHashSet(StringComparer.Ordinal) : null;
        var web = Opiniones("web_reviews.csv", "Web",
            ["IdReview", "IdCliente", "IdProducto", "Fecha", "Comentario", "Rating"]);
        var encuestas = Opiniones("surveys_part1.csv", "Encuesta",
            ["IdOpinion", "IdCliente", "IdProducto", "Fecha", "Comentario", "Clasificación", "PuntajeSatisfacción", "Fuente"]);
        var redes = Opiniones("social_comments.csv", "RedSocial",
            ["IdComment", "IdCliente", "IdProducto", "Fuente", "Fecha", "Comentario"]);
        return new(clientes, productos, fuentes, web, encuestas, redes);

        ResultadoArchivo<OpinionEntrada> Opiniones(string archivo, string canal, string[] columnas) =>
            ValidarArchivo(directorio, archivo, columnas,
                fila => validador.Opinion(fila, canal, idsClientes, idsProductos),
                opinion => opinion.IdExterno, cancellationToken);
    }

    private ResultadoArchivo<T> ValidarArchivo<T>(
        string directorio, string archivo, string[] columnas,
        Func<IReadOnlyDictionary<string, string>, (T Datos, IReadOnlyList<string> Errores)> convertir,
        Func<T, string> clave, CancellationToken cancellationToken)
    {
        DocumentoCsv documento;
        try
        {
            documento = lector.Leer(Path.Combine(directorio, archivo), columnas, cancellationToken);
        }
        catch (FileNotFoundException)
        {
            return new(archivo, [], [], 0, "Archivo no encontrado.");
        }
        catch (DirectoryNotFoundException)
        {
            return new(archivo, [], [], 0, "Directorio no encontrado.");
        }
        catch (UnauthorizedAccessException)
        {
            return new(archivo, [], [], 0, "No se permite leer el archivo.");
        }
        catch (ErrorArchivoCsvException error)
        {
            return new(archivo, [], [], 0, error.Message);
        }
        catch (DecoderFallbackException)
        {
            return new(archivo, [], [], 0, "El archivo no contiene UTF-8 valido.");
        }
        catch (IOException)
        {
            return new(archivo, [], [], 0, "Fallo de lectura del archivo.");
        }

        var aptos = new List<RegistroValidado<T>>();
        var rechazos = documento.Rechazos.ToList();
        var vistos = new Dictionary<string, T>(StringComparer.OrdinalIgnoreCase);
        long omitidos = 0;
        foreach (var fila in documento.Filas)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var (datos, errores) = convertir(fila.Campos);
            if (errores.Count > 0)
            {
                rechazos.Add(new(fila.Registro, fila.Linea, errores));
                continue;
            }
            var id = clave(datos);
            if (vistos.TryGetValue(id, out var anterior))
            {
                if (EqualityComparer<T>.Default.Equals(anterior, datos))
                    omitidos++;
                else
                    rechazos.Add(new(fila.Registro, fila.Linea, ["Conflicto: clave repetida con contenido diferente."]));
                continue;
            }
            vistos.Add(id, datos);
            aptos.Add(new(fila.Registro, fila.Linea, datos));
        }
        return new(archivo, aptos.AsReadOnly(),
            rechazos.OrderBy(rechazo => rechazo.Registro).ToList().AsReadOnly(), omitidos);
    }
}
