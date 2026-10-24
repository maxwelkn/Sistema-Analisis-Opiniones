using ETL.Entities;
using ETL.Entities.Carga;
using ETL.Entities.Contratos;
using ETL.Entities.Validacion;

namespace ETL.BLL.Carga;

public sealed class ServicioCarga(IFabricaSesionCarga fabrica)
{
    private static readonly (string Canal, string Origen, string Tipo)[] Fuentes =
    [
        ("Web", "web_reviews", "Web"),
        ("Encuesta", "EncuestaInterna", "CSV"),
        ("RedSocial", "Instagram", "Red Social"),
        ("RedSocial", "Twitter", "Red Social"),
        ("RedSocial", "Facebook", "Red Social")
    ];

    public async Task<ResultadoCarga> CargarAsync(
        ResultadoValidacion validacion, CancellationToken cancellationToken = default)
    {
        var conteos = validacion.Archivos.ToDictionary(archivo => archivo.Archivo,
            archivo => new ConteoArchivoCarga(archivo), StringComparer.Ordinal);
        CopiarRechazos(validacion.Clientes);
        CopiarRechazos(validacion.Productos);
        CopiarRechazos(validacion.Fuentes);
        CopiarRechazos(validacion.Web);
        CopiarRechazos(validacion.Encuestas);
        CopiarRechazos(validacion.Redes);
        var estado = EstadoCarga.NoIniciada;
        string? error = null;
        var cancelada = false;
        var tecnicasInsertadas = 0;
        var tecnicasOmitidas = 0;
        var tecnicasConflicto = 0;
        if (!validacion.Completa)
            return Resultado("La estructura CSV esta incompleta; no se inicio la carga SQL.");

        ISesionCarga? sesion = null;
        var confirmacionIntentada = false;
        try
        {
            sesion = await fabrica.AbrirAsync(cancellationToken);
            var clientes = await CargarCatalogo(validacion.Clientes, sesion.CargarClienteAsync, cliente => cliente.IdExterno);
            var productos = await CargarCatalogo(validacion.Productos, sesion.CargarProductoAsync, producto => producto.IdExterno);
            await CargarCatalogo(validacion.Fuentes, sesion.CargarFuenteAsync, fuente => fuente.IdExterno);
            var fuentes = new Dictionary<(string Canal, string Origen), int>();
            var ahora = DateTime.UtcNow;
            ahora = ahora.AddTicks(-(ahora.Ticks % TimeSpan.TicksPerSecond));
            foreach (var fuente in Fuentes)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var idExterno = $"ETL:{fuente.Canal}:{fuente.Origen}";
                var existente = await sesion.ObtenerFuenteAsync(idExterno, cancellationToken);
                var datos = new FuenteDatos(idExterno, fuente.Tipo, existente?.FechaCarga ?? ahora);
                var respuesta = await sesion.CargarFuenteAsync(datos, cancellationToken);
                switch (respuesta.Estado)
                {
                    case EstadoPersistencia.Insertado:
                        tecnicasInsertadas++;
                        break;
                    case EstadoPersistencia.Omitido:
                        tecnicasOmitidas++;
                        break;
                    case EstadoPersistencia.Conflicto:
                        tecnicasConflicto++;
                        continue;
                    default:
                        throw new ErrorPersistenciaException("Estado de fuente tecnica no reconocido.");
                }
                fuentes.Add((fuente.Canal, fuente.Origen), respuesta.Id);
            }
            await CargarOpiniones(validacion.Web);
            await CargarOpiniones(validacion.Encuestas);
            await CargarOpiniones(validacion.Redes);
            cancellationToken.ThrowIfCancellationRequested();
            confirmacionIntentada = true;
            await sesion.ConfirmarAsync(cancellationToken);
            estado = EstadoCarga.Confirmada;

            async Task CargarOpiniones(ResultadoArchivo<OpinionEntrada> archivo)
            {
                foreach (var registro in archivo.Aptos)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    var entrada = registro.Datos;
                    var motivos = new List<string>();
                    int? idCliente = null;
                    if (entrada.IdClienteExterno is not null)
                    {
                        if (clientes.TryGetValue(entrada.IdClienteExterno, out var cliente))
                            idCliente = cliente;
                        else
                            motivos.Add("IdCliente: maestro rechazado por conflicto SQL.");
                    }
                    if (!productos.TryGetValue(entrada.IdProductoExterno, out var idProducto))
                        motivos.Add("IdProducto: maestro rechazado por conflicto SQL.");
                    if (!fuentes.TryGetValue((entrada.Canal, entrada.FuenteOrigen), out var idFuente))
                        motivos.Add("Fuente: metadato tecnico rechazado por conflicto SQL.");
                    var conteo = conteos[archivo.Archivo];
                    if (motivos.Count > 0)
                    {
                        conteo.AgregarRechazo(registro.Registro, registro.Linea, motivos);
                        continue;
                    }
                    var opinion = new Opinion(entrada.IdExterno, entrada.Canal, idCliente,
                        idProducto, idFuente, entrada.Fecha, entrada.Comentario, entrada.Clasificacion,
                        entrada.PuntajeSatisfaccion, entrada.IdClienteOrigen, entrada.IdProductoOrigen);
                    var respuesta = await sesion.CargarOpinionAsync(opinion, cancellationToken);
                    conteo.Registrar(respuesta.Estado, registro.Registro, registro.Linea);
                }
            }
        }
        catch (Exception fallo) when (fallo is ErrorPersistenciaException or OperationCanceledException or InvalidOperationException)
        {
            cancelada = fallo is OperationCanceledException;
            error = cancelada ? "Carga cancelada antes de completar la confirmacion."
                : "Fallo tecnico durante la carga SQL.";
            if (sesion is not null)
            {
                try
                {
                    await sesion.RevertirAsync(CancellationToken.None);
                    estado = confirmacionIntentada ? EstadoCarga.Indeterminada : EstadoCarga.Revertida;
                }
                catch (Exception reversion) when (reversion is ErrorPersistenciaException or InvalidOperationException)
                {
                    estado = EstadoCarga.Indeterminada;
                }
            }
        }
        finally
        {
            if (sesion is not null)
            {
                try
                {
                    await sesion.DisposeAsync();
                }
                catch (Exception liberacion) when (liberacion is ErrorPersistenciaException or InvalidOperationException)
                {
                    error = "No se pudo completar la liberacion de la sesion SQL.";
                    if (estado != EstadoCarga.Confirmada)
                        estado = EstadoCarga.Indeterminada;
                }
            }
        }
        return Resultado(error);

        async Task<Dictionary<string, int>> CargarCatalogo<T>(ResultadoArchivo<T> archivo,
            Func<T, CancellationToken, Task<ResultadoPersistencia<int>>> cargar, Func<T, string> clave)
        {
            var mapa = new Dictionary<string, int>(StringComparer.Ordinal);
            foreach (var registro in archivo.Aptos)
            {
                cancellationToken.ThrowIfCancellationRequested();
                var respuesta = await cargar(registro.Datos, cancellationToken);
                if (conteos[archivo.Archivo].Registrar(respuesta.Estado, registro.Registro, registro.Linea))
                    mapa.Add(clave(registro.Datos), respuesta.Id);
            }
            return mapa;
        }

        void CopiarRechazos<T>(ResultadoArchivo<T> archivo)
        {
            foreach (var rechazo in archivo.Rechazos)
                conteos[archivo.Archivo].AgregarRechazo(rechazo.Registro, rechazo.Linea, rechazo.Motivos);
        }

        ResultadoCarga Resultado(string? mensaje)
        {
            var confirmada = estado == EstadoCarga.Confirmada;
            var insertadas = confirmada ? tecnicasInsertadas : 0;
            return new(estado, conteos.Values.Select(conteo => conteo.Resumen(confirmada)).ToArray(),
                new(insertadas, tecnicasOmitidas, tecnicasConflicto,
                    Fuentes.Length - insertadas - tecnicasOmitidas - tecnicasConflicto),
                conteos.Values.SelectMany(conteo => conteo.Rechazos).ToArray(), mensaje, cancelada);
        }
    }
}
