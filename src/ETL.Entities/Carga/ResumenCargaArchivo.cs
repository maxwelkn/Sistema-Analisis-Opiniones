namespace ETL.Entities.Carga;

public sealed record ResumenCargaArchivo(
    string Archivo, long Procesados, long Insertados, long Omitidos,
    long Rechazados, long Pendientes);
