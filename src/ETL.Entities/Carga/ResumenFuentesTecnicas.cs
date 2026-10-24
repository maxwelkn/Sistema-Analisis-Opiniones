namespace ETL.Entities.Carga;

public sealed record ResumenFuentesTecnicas(
    int Insertadas, int Omitidas, int Conflictos, int Pendientes);
