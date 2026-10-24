namespace ETL.Entities.Carga;

public sealed class ErrorPersistenciaException(string mensaje, Exception? causa = null)
    : Exception(mensaje, causa);
