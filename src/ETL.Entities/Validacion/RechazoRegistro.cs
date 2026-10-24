namespace ETL.Entities.Validacion;

public sealed record RechazoRegistro(
    long Registro, long Linea, IReadOnlyList<string> Motivos);
