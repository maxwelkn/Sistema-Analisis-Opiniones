using ETL.Entities.Validacion;

namespace ETL.BLL.Lectura;

internal sealed record DocumentoCsv(
    IReadOnlyList<FilaCsv> Filas, IReadOnlyList<RechazoRegistro> Rechazos);
