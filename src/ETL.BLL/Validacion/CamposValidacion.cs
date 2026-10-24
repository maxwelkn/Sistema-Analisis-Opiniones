using System.Globalization;
using System.Net.Mail;

namespace ETL.BLL.Validacion;

internal sealed class CamposValidacion(IReadOnlyDictionary<string, string> campos)
{
    public List<string> Errores { get; } = [];

    public string Texto(string campo, int maximo, bool obligatorio = true, bool recortar = true)
    {
        var valor = recortar ? campos[campo].Trim() : campos[campo];
        if (string.IsNullOrWhiteSpace(valor))
        {
            if (obligatorio)
                Errores.Add($"{campo}: campo obligatorio.");
            return string.Empty;
        }
        if (valor.Length > maximo)
            Errores.Add($"{campo}: supera la longitud maxima de {maximo}.");
        return valor;
    }

    public string? Origen(string campo, bool obligatorio)
    {
        var valor = Texto(campo, 50, obligatorio, recortar: false);
        return valor.Length == 0 ? null : valor;
    }

    public string? IdNumerico(string campo, char? prefijo = null, bool obligatorio = true)
    {
        var texto = Texto(campo, 50, obligatorio);
        if (texto.Length == 0)
            return null;
        var digitos = texto;
        if (prefijo is not null)
        {
            if (texto[0] != prefijo)
            {
                Errores.Add($"{campo}: prefijo de identificador no valido.");
                return null;
            }
            digitos = texto[1..];
        }
        if (digitos.Length == 0 || digitos.Any(caracter => caracter is < '0' or > '9') ||
            !int.TryParse(digitos, NumberStyles.None, CultureInfo.InvariantCulture, out var numero) || numero <= 0)
        {
            Errores.Add($"{campo}: se requiere un identificador numerico positivo.");
            return null;
        }
        return numero.ToString(CultureInfo.InvariantCulture);
    }

    public DateTime Fecha(string campo)
    {
        var valor = Texto(campo, 10);
        if (DateTime.TryParseExact(valor, "yyyy-MM-dd", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out var fecha))
            return fecha;
        Errores.Add($"{campo}: fecha no valida; se requiere yyyy-MM-dd.");
        return default;
    }

    public byte Puntaje(string campo)
    {
        var valor = Texto(campo, 1);
        if (byte.TryParse(valor, NumberStyles.None, CultureInfo.InvariantCulture, out var puntaje)
            && puntaje is >= 1 and <= 5)
            return puntaje;
        Errores.Add($"{campo}: se requiere un entero entre 1 y 5.");
        return default;
    }

    public string Permitido(string campo, int maximo, params string[] permitidos)
    {
        var valor = Texto(campo, maximo);
        if (!permitidos.Contains(valor, StringComparer.Ordinal))
            Errores.Add($"{campo}: valor no permitido.");
        return valor;
    }

    public string? Email()
    {
        var valor = Texto("Email", 254, obligatorio: false);
        if (valor.Length == 0)
            return null;
        if (!MailAddress.TryCreate(valor, out var direccion) || direccion.Address != valor)
            Errores.Add("Email: formato no valido.");
        return valor;
    }
}
