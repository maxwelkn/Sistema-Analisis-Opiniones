namespace ETL.Entities.Validacion;

public sealed record ResultadoArchivo<T>(
    string Archivo,
    IReadOnlyList<RegistroValidado<T>> Aptos,
    IReadOnlyList<RechazoRegistro> Rechazos,
    long Omitidos,
    string? ErrorEstructura = null)
{
    public ResumenArchivo Resumen => new(
        Archivo, Aptos.Count + Rechazos.Count + Omitidos,
        Aptos.Count, Rechazos.Count, Omitidos, ErrorEstructura);
}
