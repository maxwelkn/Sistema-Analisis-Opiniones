using ETL.BLL.Carga;
using ETL.DAL;
using ETL.Entities.Carga;
using ETL.Entities.Contratos;
using ETL.Entities.Validacion;

namespace ETL.Consola;

internal static class ComandoCarga
{
    public static async Task<int> EjecutarAsync(ResultadoValidacion validacion,
        string directorioReportes, TextWriter salida, TextWriter errores,
        CancellationToken cancellationToken, IFabricaSesionCarga? fabrica = null)
    {
        if (!validacion.Completa)
        {
            await errores.WriteLineAsync("No se inicio SQL: corrige los errores de estructura de los CSV.");
            return 1;
        }
        if (fabrica is null)
        {
            var conexion = Environment.GetEnvironmentVariable("ETL_SQL_CONNECTION");
            if (string.IsNullOrWhiteSpace(conexion))
            {
                await errores.WriteLineAsync("Define ETL_SQL_CONNECTION para ejecutar --cargar.");
                return 1;
            }
            fabrica = new FabricaSesionSql(conexion);
        }
        await using var reporte = new ReporteCarga(directorioReportes);
        var resultado = await new ServicioCarga(fabrica).CargarAsync(validacion, cancellationToken);
        await salida.WriteLineAsync($"Estado de carga: {resultado.Estado}");
        await salida.WriteLineAsync($"{"Archivo",-23} {"Procesados",10} {"Insertados",10} {"Omitidos",9} {"Rechazados",11} {"Pendientes",10}");
        foreach (var archivo in resultado.Archivos)
            await salida.WriteLineAsync($"{archivo.Archivo,-23} {archivo.Procesados,10} {archivo.Insertados,10} {archivo.Omitidos,9} {archivo.Rechazados,11} {archivo.Pendientes,10}");
        await salida.WriteLineAsync($"{"TOTAL CSV",-23} {resultado.Procesados,10} {resultado.Insertados,10} {resultado.Omitidos,9} {resultado.Rechazados,11} {resultado.Pendientes,10}");
        var fuentes = resultado.FuentesTecnicas;
        await salida.WriteLineAsync($"Fuentes tecnicas aparte: {fuentes.Insertadas} insertadas, {fuentes.Omitidas} omitidas, {fuentes.Conflictos} conflictos, {fuentes.Pendientes} pendientes.");
        if (resultado.Error is not null)
            await errores.WriteLineAsync(resultado.Error);
        if (resultado.Estado == EstadoCarga.Indeterminada)
            await errores.WriteLineAsync("Confirmacion no verificable: reconcilia SQL antes de repetir la carga.");
        try
        {
            await reporte.GuardarAsync(resultado);
            await salida.WriteLineAsync($"Reporte local: {reporte.Ruta}");
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            await errores.WriteLineAsync($"La carga quedo {resultado.Estado}; no se pudo guardar su reporte.");
            return 1;
        }
        if (resultado.Estado == EstadoCarga.Indeterminada || resultado.Error is not null && !resultado.Cancelada)
            return 1;
        if (resultado.Cancelada)
            return 130;
        return resultado.Estado != EstadoCarga.Confirmada ? 1
            : resultado.Rechazados > 0 || fuentes.Conflictos > 0 ? 2 : 0;
    }
}
