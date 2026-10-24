namespace ETL.BLL.Lectura;

internal sealed record FilaCsv(
    long Registro, long Linea, IReadOnlyDictionary<string, string> Campos);
