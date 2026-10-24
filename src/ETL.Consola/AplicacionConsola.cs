using ETL.BLL.Validacion;
using ETL.Entities.Carga;
using ETL.Entities.Contratos;

namespace ETL.Consola;

public static class AplicacionConsola
{
    public static async Task<int> EjecutarAsync(
        string[] argumentos, TextWriter salida, TextWriter errores,
        CancellationToken cancellationToken = default, IFabricaSesionCarga? fabricaCarga = null)
    {
        if (argumentos.Length == 0 || argumentos is ["--help"])
        {
            await salida.WriteLineAsync("Uso: ETL.Consola --validar <carpeta-csv> [--reportes <carpeta-local>]");
            await salida.WriteLineAsync("Valida los seis CSV y genera un resumen; no escribe en SQL Server.");
            await salida.WriteLineAsync("Carga SQL: ETL.Consola --cargar <carpeta-csv> [--reportes <carpeta-local>]");
            await salida.WriteLineAsync("--cargar requiere ETL_SQL_CONNECTION y confirma los datos validos en SQL Server.");
            return 0;
        }
        if (argumentos.Length is not (2 or 4) || argumentos[0] is not ("--validar" or "--cargar") ||
            (argumentos.Length == 4 && argumentos[2] != "--reportes"))
        {
            await errores.WriteLineAsync("Argumentos no validos. Consulta --help.");
            return 1;
        }
        try
        {
            var directorio = Path.GetFullPath(argumentos[1]);
            var reportes = argumentos.Length == 4
                ? Path.GetFullPath(argumentos[3]) : ReporteValidacion.DirectorioPredeterminado();
            var resultado = new ServicioValidacionCsv().Validar(directorio, cancellationToken);
            await salida.WriteLineAsync("Validacion CSV sin escritura en SQL Server");
            await salida.WriteLineAsync($"{"Archivo",-23} {"Procesados",10} {"Aptos",7} {"Omitidos",9} {"Rechazados",11}");
            foreach (var archivo in resultado.Archivos)
            {
                await salida.WriteLineAsync($"{archivo.Archivo,-23} {archivo.Procesados,10} {archivo.Aptos,7} {archivo.Omitidos,9} {archivo.Rechazados,11}");
                if (archivo.ErrorEstructura is not null)
                    await errores.WriteLineAsync($"{archivo.Archivo}: {archivo.ErrorEstructura}");
            }
            await salida.WriteLineAsync($"{"TOTAL",-23} {resultado.Procesados,10} {resultado.Aptos,7} {resultado.Omitidos,9} {resultado.Rechazados,11}");
            if (!resultado.Completa)
                await errores.WriteLineAsync("Validacion incompleta: los archivos con fallo no aportan filas al total.");
            if (argumentos[0] == "--cargar")
                return await ComandoCarga.EjecutarAsync(resultado, reportes, salida, errores,
                    cancellationToken, fabricaCarga);
            var ruta = await ReporteValidacion.GuardarAsync(resultado, reportes, cancellationToken);
            await salida.WriteLineAsync($"Reporte local: {ruta}");
            return !resultado.Completa ? 1 : resultado.Rechazados > 0 ? 2 : 0;
        }
        catch (OperationCanceledException)
        {
            await errores.WriteLineAsync("Operacion cancelada antes de iniciar la carga SQL.");
            return 130;
        }
        catch (ErrorPersistenciaException)
        {
            await errores.WriteLineAsync("No se pudo configurar o iniciar el acceso a SQL Server.");
            return 1;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or ArgumentException)
        {
            await errores.WriteLineAsync("No se pudo completar la validacion o guardar el reporte. Revisa las rutas y permisos.");
            return 1;
        }
    }
}
