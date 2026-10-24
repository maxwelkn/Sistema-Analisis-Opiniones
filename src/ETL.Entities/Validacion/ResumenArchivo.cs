namespace ETL.Entities.Validacion;

public sealed record ResumenArchivo(
    string Archivo,
    long Procesados,
    long Aptos,
    long Rechazados,
    long Omitidos,
    string? ErrorEstructura);
