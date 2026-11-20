namespace ETL.Entities.Contratos;

public interface IExtractor
{
    string Fuente { get; }
    IAsyncEnumerable<IReadOnlyDictionary<string, object?>> ExtraerAsync(
        CancellationToken cancellationToken);
}
