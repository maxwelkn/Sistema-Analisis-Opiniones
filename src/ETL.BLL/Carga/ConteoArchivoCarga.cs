using ETL.Entities.Carga;
using ETL.Entities.Validacion;

namespace ETL.BLL.Carga;

internal sealed class ConteoArchivoCarga(ResumenArchivo validacion)
{
    public long InsertadosProvisionales { get; private set; }
    public long Omitidos { get; private set; } = validacion.Omitidos;
    public List<RechazoCarga> Rechazos { get; } = [];

    public void AgregarRechazo(long registro, long linea, IReadOnlyList<string> motivos) =>
        Rechazos.Add(new(validacion.Archivo, registro, linea, motivos));

    public bool Registrar(EstadoPersistencia estado, long registro, long linea)
    {
        switch (estado)
        {
            case EstadoPersistencia.Insertado:
                InsertadosProvisionales++;
                return true;
            case EstadoPersistencia.Omitido:
                Omitidos++;
                return true;
            case EstadoPersistencia.Conflicto:
                AgregarRechazo(registro, linea, ["Conflicto SQL: clave existente con contenido diferente."]);
                return false;
            default:
                throw new ErrorPersistenciaException("Estado de persistencia no reconocido.");
        }
    }

    public ResumenCargaArchivo Resumen(bool confirmada)
    {
        var insertados = confirmada ? InsertadosProvisionales : 0;
        return new(validacion.Archivo, validacion.Procesados, insertados, Omitidos, Rechazos.Count,
            validacion.Procesados - insertados - Omitidos - Rechazos.Count);
    }
}
