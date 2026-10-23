namespace ETL.Entities;

public sealed record FuenteDatos(
    string IdExterno,
    string TipoFuente,
    DateTime FechaCarga);
