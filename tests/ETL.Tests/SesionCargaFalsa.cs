using ETL.Entities;
using ETL.Entities.Carga;
using ETL.Entities.Contratos;

namespace ETL.Tests;

public sealed class SesionCargaFalsa : ISesionCarga
{
    public EstadoPersistencia EstadoCliente { get; set; } = EstadoPersistencia.Insertado;
    public EstadoPersistencia EstadoProducto { get; set; } = EstadoPersistencia.Insertado;
    public EstadoPersistencia EstadoFuente { get; set; } = EstadoPersistencia.Insertado;
    public EstadoPersistencia EstadoOpinion { get; set; } = EstadoPersistencia.Insertado;
    public EstadoPersistencia EstadoTecnica { get; set; } = EstadoPersistencia.Insertado;
    public DateTime? FechaExistente { get; set; }
    public bool FallarOpinion { get; set; }
    public bool FallarConfirmacion { get; set; }
    public bool FallarReversion { get; set; }
    public bool CancelarOpinion { get; set; }
    public bool Confirmada { get; private set; }
    public bool Revertida { get; private set; }
    public bool Liberada { get; private set; }
    public CancellationToken TokenReversion { get; private set; }
    public List<FuenteDatos> Fuentes { get; } = [];
    public List<Opinion> Opiniones { get; } = [];

    public Task<FuenteDatos?> ObtenerFuenteAsync(string idExterno, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var tipo = idExterno.Contains(":Web:", StringComparison.Ordinal) ? "Web"
            : idExterno.Contains(":Encuesta:", StringComparison.Ordinal) ? "CSV" : "Red Social";
        FuenteDatos? fuente = FechaExistente is { } fecha ? new(idExterno, tipo, fecha) : null;
        return Task.FromResult(fuente);
    }

    public Task<ResultadoPersistencia<int>> CargarClienteAsync(Cliente cliente, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(new ResultadoPersistencia<int>(101, EstadoCliente));
    }

    public Task<ResultadoPersistencia<int>> CargarProductoAsync(Producto producto, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(new ResultadoPersistencia<int>(201, EstadoProducto));
    }

    public Task<ResultadoPersistencia<int>> CargarFuenteAsync(FuenteDatos fuente, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Fuentes.Add(fuente);
        return Task.FromResult(new ResultadoPersistencia<int>(300 + Fuentes.Count,
            fuente.IdExterno.StartsWith("ETL:", StringComparison.Ordinal) ? EstadoTecnica : EstadoFuente));
    }

    public Task<ResultadoPersistencia<long>> CargarOpinionAsync(Opinion opinion, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (CancelarOpinion)
            throw new OperationCanceledException();
        if (FallarOpinion)
            throw new ErrorPersistenciaException("Fallo de prueba.");
        Opiniones.Add(opinion);
        return Task.FromResult(new ResultadoPersistencia<long>(400 + Opiniones.Count, EstadoOpinion));
    }

    public Task ConfirmarAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (FallarConfirmacion)
            throw new ErrorPersistenciaException("Fallo de confirmacion de prueba.");
        Confirmada = true;
        return Task.CompletedTask;
    }

    public Task RevertirAsync(CancellationToken cancellationToken = default)
    {
        TokenReversion = cancellationToken;
        if (FallarReversion)
            throw new ErrorPersistenciaException("Fallo de reversion de prueba.");
        Revertida = true;
        return Task.CompletedTask;
    }

    public ValueTask DisposeAsync()
    {
        Liberada = true;
        return ValueTask.CompletedTask;
    }
}

public sealed class FabricaSesionFalsa(SesionCargaFalsa sesion) : IFabricaSesionCarga
{
    public int Aperturas { get; private set; }
    public bool FallarApertura { get; set; }

    public Task<ISesionCarga> AbrirAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Aperturas++;
        if (FallarApertura)
            throw new ErrorPersistenciaException("Fallo de apertura de prueba.");
        return Task.FromResult<ISesionCarga>(sesion);
    }
}
