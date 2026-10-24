using System.Text;
using ETL.BLL.Validacion;
using ETL.Entities.Validacion;

namespace ETL.Tests;

public sealed class ConjuntoCsv : IDisposable
{
    public string Directorio { get; } = Path.Combine(Path.GetTempPath(), "etl-tests-" + Guid.NewGuid().ToString("N"));

    public ConjuntoCsv()
    {
        Directory.CreateDirectory(Directorio);
        Escribir("clients.csv", "IdCliente,Nombre,Email\n1,Cliente de prueba,prueba@example.test\n");
        Escribir("products.csv", "IdProducto,Nombre,Categoría\n1,Producto de prueba,Pruebas\n");
        Escribir("fuente_datos.csv", "IdFuente,TipoFuente,FechaCarga\nF001,Web,2025-04-10\n");
        Escribir("web_reviews.csv", "IdReview,IdCliente,IdProducto,Fecha,Comentario,Rating\nW0001,C001,P001,2025-04-10,Comentario web,5\n");
        Escribir("surveys_part1.csv", "IdOpinion,IdCliente,IdProducto,Fecha,Comentario,Clasificación,PuntajeSatisfacción,Fuente\n1,1,1,2025-04-10,Comentario encuesta,Positiva,4,EncuestaInterna\n");
        Escribir("social_comments.csv", "IdComment,IdCliente,IdProducto,Fuente,Fecha,Comentario\nT0001,C001,P001,Instagram,2025-04-10,Comentario social\n");
    }

    public void Escribir(string archivo, string contenido) =>
        File.WriteAllText(Path.Combine(Directorio, archivo), contenido, new UTF8Encoding(false));

    public ResultadoValidacion Validar(CancellationToken cancellationToken) =>
        new ServicioValidacionCsv().Validar(Directorio, cancellationToken);

    public void Dispose()
    {
        var destino = Path.GetFullPath(Directorio);
        var temporal = Path.TrimEndingDirectorySeparator(Path.GetFullPath(Path.GetTempPath()));
        if (!string.Equals(Path.GetDirectoryName(destino), temporal, StringComparison.OrdinalIgnoreCase) ||
            !Path.GetFileName(destino).StartsWith("etl-tests-", StringComparison.Ordinal))
            throw new InvalidOperationException("El directorio de pruebas no pertenece al destino temporal previsto.");
        Directory.Delete(destino, recursive: true);
    }
}
