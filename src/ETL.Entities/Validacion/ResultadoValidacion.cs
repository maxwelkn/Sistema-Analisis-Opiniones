namespace ETL.Entities.Validacion;

public sealed record ResultadoValidacion(
    ResultadoArchivo<Cliente> Clientes,
    ResultadoArchivo<Producto> Productos,
    ResultadoArchivo<FuenteDatos> Fuentes,
    ResultadoArchivo<OpinionEntrada> Web,
    ResultadoArchivo<OpinionEntrada> Encuestas,
    ResultadoArchivo<OpinionEntrada> Redes)
{
    public IReadOnlyList<ResumenArchivo> Archivos =>
        [Clientes.Resumen, Productos.Resumen, Fuentes.Resumen,
         Web.Resumen, Encuestas.Resumen, Redes.Resumen];

    public bool Completa => Archivos.All(archivo => archivo.ErrorEstructura is null);
    public long Procesados => Archivos.Sum(archivo => archivo.Procesados);
    public long Aptos => Archivos.Sum(archivo => archivo.Aptos);
    public long Rechazados => Archivos.Sum(archivo => archivo.Rechazados);
    public long Omitidos => Archivos.Sum(archivo => archivo.Omitidos);
}
