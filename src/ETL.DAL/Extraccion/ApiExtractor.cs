using System.Net.Http.Headers;
using System.Runtime.CompilerServices;
using System.Text.Json;
using ETL.Entities.Contratos;

namespace ETL.DAL.Extraccion;

public sealed class ApiExtractor : IExtractor
{
    private readonly HttpClient cliente;
    private readonly Uri url;
    private readonly string? token;

    public ApiExtractor(HttpClient cliente, Uri url, string? token, bool permitirHttpLocal)
    {
        if (!url.IsAbsoluteUri || url.UserInfo.Length != 0 || url.Fragment.Length != 0 ||
            (url.Scheme != Uri.UriSchemeHttps &&
                (url.Scheme != Uri.UriSchemeHttp || !url.IsLoopback || !permitirHttpLocal || token is not null)))
            throw new ArgumentException("La URL de API debe usar HTTPS. La demo HTTP exige loopback y ningún token.", nameof(url));

        this.cliente = cliente;
        this.url = url;
        this.token = token;
    }

    public string Fuente => "comentarios-api";

    public async IAsyncEnumerable<IReadOnlyDictionary<string, object?>> ExtraerAsync(
        [EnumeratorCancellation] CancellationToken cancellationToken)
    {
        using var plazo = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        plazo.CancelAfter(TimeSpan.FromMinutes(2));
        using var solicitud = new HttpRequestMessage(HttpMethod.Get, url);
        solicitud.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        if (token is not null)
            solicitud.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var respuesta = await cliente.SendAsync(solicitud, HttpCompletionOption.ResponseHeadersRead,
            plazo.Token);
        respuesta.EnsureSuccessStatusCode();
        await using var contenido = await respuesta.Content.ReadAsStreamAsync(plazo.Token);

        await foreach (var registro in JsonSerializer.DeserializeAsyncEnumerable<Dictionary<string, object?>>(
            contenido, cancellationToken: plazo.Token))
        {
            if (registro is null || !EsTexto(registro, "IdComment") || !EsTexto(registro, "Comentario"))
                throw new JsonException("Cada comentario requiere IdComment y Comentario de tipo texto.");

            yield return registro;
        }
    }

    private static bool EsTexto(IReadOnlyDictionary<string, object?> registro, string campo) =>
        registro.TryGetValue(campo, out var valor) && valor is JsonElement { ValueKind: JsonValueKind.String };
}
