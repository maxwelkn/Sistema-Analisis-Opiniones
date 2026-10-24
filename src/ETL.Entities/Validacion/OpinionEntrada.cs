namespace ETL.Entities.Validacion;

public sealed record OpinionEntrada(
    string IdExterno,
    string Canal,
    string? IdClienteExterno,
    string IdProductoExterno,
    string FuenteOrigen,
    DateTime Fecha,
    string Comentario,
    string? Clasificacion,
    byte? PuntajeSatisfaccion,
    string? IdClienteOrigen,
    string IdProductoOrigen);
