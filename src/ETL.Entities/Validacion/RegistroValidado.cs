namespace ETL.Entities.Validacion;

public sealed record RegistroValidado<T>(long Registro, long Linea, T Datos);
