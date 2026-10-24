namespace ETL.Entities.Carga;

public sealed record RechazoCarga(
    string Archivo, long Registro, long Linea, IReadOnlyList<string> Motivos);
