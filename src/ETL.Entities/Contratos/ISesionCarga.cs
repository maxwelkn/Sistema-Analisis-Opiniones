using ETL.Entities.Carga;

namespace ETL.Entities.Contratos;

public interface ISesionCarga : IAsyncDisposable
{
    Task<FuenteDatos?> ObtenerFuenteAsync(
        string idExterno, CancellationToken cancellationToken = default);

    Task<ResultadoPersistencia<int>> CargarClienteAsync(
        Cliente cliente, CancellationToken cancellationToken = default);

    Task<ResultadoPersistencia<int>> CargarProductoAsync(
        Producto producto, CancellationToken cancellationToken = default);

    Task<ResultadoPersistencia<int>> CargarFuenteAsync(
        FuenteDatos fuente, CancellationToken cancellationToken = default);

    Task<ResultadoPersistencia<long>> CargarOpinionAsync(
        Opinion opinion, CancellationToken cancellationToken = default);

    Task ConfirmarAsync(CancellationToken cancellationToken = default);

    Task RevertirAsync(CancellationToken cancellationToken = default);
}
