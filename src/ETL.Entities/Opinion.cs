namespace ETL.Entities;

public sealed record Opinion(
    string IdExterno,
    string Canal,
    int? IdCliente,
    int IdProducto,
    int IdFuente,
    DateTime Fecha,
    string Comentario,
    string? Clasificacion,
    byte? PuntajeSatisfaccion,
    string? IdClienteOrigen,
    string IdProductoOrigen);
