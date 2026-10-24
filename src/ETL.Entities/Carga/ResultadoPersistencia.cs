namespace ETL.Entities.Carga;

public sealed record ResultadoPersistencia<TId>(TId Id, EstadoPersistencia Estado)
    where TId : struct;
