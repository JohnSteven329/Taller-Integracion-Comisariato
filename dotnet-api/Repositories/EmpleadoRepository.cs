using Comisariato.Api.DTOs;
using Npgsql;

namespace Comisariato.Api.Repositories;

public sealed class EmpleadoRepository : IEmpleadoRepository
{
    private readonly NpgsqlDataSource _dataSource;

    public EmpleadoRepository(NpgsqlDataSource dataSource)
    {
        _dataSource = dataSource;
    }

    public async Task<bool> ExisteAsync(int empleadoId, CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT EXISTS (
                SELECT 1 FROM public.empleados WHERE empleadoid = @empleado
            )
            """;

        await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("empleado", empleadoId);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is bool exists && exists;
    }

    public async Task<List<VentaEmpleadoResponse>> VentasAsync(
        int empleadoId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT ventaid, numerofactura, fechaventa, total
            FROM public.fn_ventasporempleado(@empleado)
            ORDER BY fechaventa DESC, ventaid DESC
            """;

        await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("empleado", empleadoId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var ventas = new List<VentaEmpleadoResponse>();
        while (await reader.ReadAsync(cancellationToken))
        {
            ventas.Add(new VentaEmpleadoResponse(
                reader.GetInt32(0),
                reader.GetString(1),
                reader.GetDateTime(2),
                reader.GetDecimal(3)));
        }

        return ventas;
    }
}