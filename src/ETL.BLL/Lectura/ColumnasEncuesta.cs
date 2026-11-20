namespace ETL.BLL.Lectura;

internal static class ColumnasEncuesta
{
    public static IReadOnlyList<string> Valores { get; } =
        ["IdOpinion", "IdCliente", "IdProducto", "Fecha", "Comentario",
            "Clasificación", "PuntajeSatisfacción", "Fuente"];
}
