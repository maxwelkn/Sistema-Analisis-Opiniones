namespace ETL.Entities.Carga;

public sealed record ResultadoCarga(
    EstadoCarga Estado,
    IReadOnlyList<ResumenCargaArchivo> Archivos,
    ResumenFuentesTecnicas FuentesTecnicas,
    IReadOnlyList<RechazoCarga> Rechazos,
    string? Error = null,
    bool Cancelada = false)
{
    public long Procesados => Archivos.Sum(archivo => archivo.Procesados);
    public long Insertados => Archivos.Sum(archivo => archivo.Insertados);
    public long Omitidos => Archivos.Sum(archivo => archivo.Omitidos);
    public long Rechazados => Archivos.Sum(archivo => archivo.Rechazados);
    public long Pendientes => Archivos.Sum(archivo => archivo.Pendientes);
}
