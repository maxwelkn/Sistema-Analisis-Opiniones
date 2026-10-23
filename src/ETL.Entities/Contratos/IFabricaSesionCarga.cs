namespace ETL.Entities.Contratos;

public interface IFabricaSesionCarga
{
    Task<ISesionCarga> AbrirAsync(CancellationToken cancellationToken = default);
}
