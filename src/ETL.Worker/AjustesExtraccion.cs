namespace ETL.Worker;

internal sealed record AjustesExtraccion(
    string EncuestasCsv, string DirectorioTemporal, string ConexionSql,
    Uri UrlApi, string? TokenApi, bool PermitirHttpLocal)
{
    public static AjustesExtraccion Leer(IConfiguration configuracion)
    {
        var directorio = configuracion["Extraccion:DirectorioTemporal"];
        if (string.IsNullOrWhiteSpace(directorio))
        {
            var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (string.IsNullOrEmpty(local))
                throw new ArgumentException("Configura un directorio temporal privado.");
            directorio = Path.Combine(local, "SistemaAnalisisOpiniones", "staging");
        }

        if (!Uri.TryCreate(Obligatorio(configuracion, "Extraccion:Api:Url"), UriKind.Absolute, out var urlApi))
            throw new ArgumentException("Configura una URL absoluta para la API.");

        var token = configuracion["Extraccion:Api:Token"];
        return new(Path.GetFullPath(Obligatorio(configuracion, "Extraccion:EncuestasCsv")),
            Path.GetFullPath(directorio),
            Obligatorio(configuracion, "ConnectionStrings:Resenas"),
            urlApi,
            string.IsNullOrWhiteSpace(token) ? null : token,
            configuracion.GetValue<bool>("Extraccion:Api:PermitirHttpLocal"));
    }

    private static string Obligatorio(IConfiguration configuracion, string clave) =>
        configuracion[clave] is { } valor && !string.IsNullOrWhiteSpace(valor)
            ? valor : throw new ArgumentException($"Falta configurar {clave}.");
}
