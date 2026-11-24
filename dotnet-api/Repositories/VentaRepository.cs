using Comisariato.Api.DTOs;
using Comisariato.Api.Infrastructure;
using Npgsql;
using NpgsqlTypes;

namespace Comisariato.Api.Repositories;

public sealed class VentaRepository : IVentaRepository
{
    private readonly ILogger<VentaRepository> _logger;

    public VentaRepository(ILogger<VentaRepository> logger)
    {
        _logger = logger;
    }

    public async Task<VentaResponse> RegistrarAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        VentaRequest request,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await ValidarReferenciasAsync(connection, transaction, request, cancellationToken);
            await ValidarProductoYStockAsync(connection, transaction, request, cancellationToken);

            // El SQL compartido define un procedimiento con un INOUT para el ID.
            // CALL devuelve ese parámetro de salida como una fila de una columna.
            const string sql = """
                CALL public.usp_registrarventa(
                    @p_factura, @p_cliente, @p_empleado, @p_formapago,
                    @p_producto, @p_cantidad, NULL)
                """;

            int ventaId;
            await using (var command = new NpgsqlCommand(sql, connection, transaction))
            {
                command.Parameters.Add(new NpgsqlParameter("p_factura", NpgsqlDbType.Varchar)
                {
                    Value = request.NumeroFactura!
                });
                command.Parameters.Add(new NpgsqlParameter("p_cliente", NpgsqlDbType.Integer)
                {
                    Value = request.ClienteId.HasValue ? request.ClienteId.Value : DBNull.Value
                });
                command.Parameters.Add(new NpgsqlParameter("p_empleado", NpgsqlDbType.Integer)
                {
                    Value = request.EmpleadoId!.Value
                });
                command.Parameters.Add(new NpgsqlParameter("p_formapago", NpgsqlDbType.Varchar)
                {
                    Value = request.FormaPago!
                });
                command.Parameters.Add(new NpgsqlParameter("p_producto", NpgsqlDbType.Integer)
                {
                    Value = request.ProductoId!.Value
                });
                command.Parameters.Add(new NpgsqlParameter("p_cantidad", NpgsqlDbType.Integer)
                {
                    Value = request.Cantidad!.Value
                });

                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    throw new DatabaseException("El procedimiento usp_registrarventa no devolvió el ID de la venta.");
                }

                ventaId = reader.GetInt32(0);
            }

            return await ObtenerVentaAsync(connection, transaction, ventaId, cancellationToken);
        }
        catch (PostgresException ex)
        {
            _logger.LogError(ex, "Error PostgreSQL en usp_registrarventa. SQLSTATE={SqlState}", ex.SqlState);
            throw SqlErrorMapper.Map(ex, "usp_registrarventa");
        }
    }

    public async Task<VentaResponse> AnularAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        int ventaId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            int empleadoId;
            const string sqlBloqueo = """
                SELECT empleadoid, estado
                FROM public.ventas
                WHERE ventaid = @p_ventaid
                FOR UPDATE
                """;

            await using (var command = new NpgsqlCommand(sqlBloqueo, connection, transaction))
            {
                command.Parameters.Add(new NpgsqlParameter("p_ventaid", NpgsqlDbType.Integer)
                {
                    Value = ventaId
                });

                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    throw new NotFoundException($"La venta {ventaId} no existe.");
                }

                empleadoId = reader.GetInt32(0);
                var estado = reader.GetString(1);
                if (estado == "Anulada")
                {
                    throw new ConflictException("La venta ya está anulada.");
                }

                if (estado != "Completada")
                {
                    throw new ConflictException("La venta no se encuentra en un estado que permita anularla.");
                }
            }

            await using (var command = new NpgsqlCommand(
                "CALL public.usp_anularventa(@p_ventaid, @p_empleado)", connection, transaction))
            {
                command.Parameters.Add(new NpgsqlParameter("p_ventaid", NpgsqlDbType.Integer)
                {
                    Value = ventaId
                });
                command.Parameters.Add(new NpgsqlParameter("p_empleado", NpgsqlDbType.Integer)
                {
                    Value = empleadoId
                });
                await command.ExecuteNonQueryAsync(cancellationToken);
            }

            return await ObtenerVentaAsync(connection, transaction, ventaId, cancellationToken);
        }
        catch (PostgresException ex)
        {
            _logger.LogError(ex, "Error PostgreSQL en usp_anularventa. SQLSTATE={SqlState}", ex.SqlState);
            throw SqlErrorMapper.Map(ex, "usp_anularventa");
        }
    }

    private static async Task ValidarReferenciasAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        VentaRequest request,
        CancellationToken cancellationToken)
    {
        const string sqlEmpleado = """
            SELECT EXISTS (
                SELECT 1 FROM public.empleados
                WHERE empleadoid = @empleado AND activo
            )
            """;
        if (!await ConsultarExisteAsync(
            connection, transaction, sqlEmpleado, "empleado", request.EmpleadoId!.Value, cancellationToken))
        {
            throw new NotFoundException("El empleado indicado no existe o está inactivo.");
        }

        if (request.ClienteId.HasValue)
        {
            const string sqlCliente = "SELECT EXISTS (SELECT 1 FROM public.clientes WHERE clienteid = @cliente)";
            if (!await ConsultarExisteAsync(
                connection, transaction, sqlCliente, "cliente", request.ClienteId.Value, cancellationToken))
            {
                throw new NotFoundException("El cliente indicado no existe.");
            }
        }
    }

    private static async Task ValidarProductoYStockAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        VentaRequest request,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT stock
            FROM public.productos
            WHERE productoid = @producto AND activo
            FOR UPDATE
            """;

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.Add(new NpgsqlParameter("producto", NpgsqlDbType.Integer)
        {
            Value = request.ProductoId!.Value
        });
        var resultado = await command.ExecuteScalarAsync(cancellationToken);
        if (resultado is null)
        {
            throw new NotFoundException("El producto indicado no existe o está inactivo.");
        }

        var stock = Convert.ToInt32(resultado);
        if (stock < request.Cantidad!.Value)
        {
            throw new BusinessException(
                $"Stock insuficiente para el producto {request.ProductoId.Value}: disponible={stock}, solicitado={request.Cantidad.Value}.");
        }
    }

    private static async Task<bool> ConsultarExisteAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        string sql,
        string parametro,
        int valor,
        CancellationToken cancellationToken)
    {
        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.Add(new NpgsqlParameter(parametro, NpgsqlDbType.Integer) { Value = valor });
        var resultado = await command.ExecuteScalarAsync(cancellationToken);
        return resultado is bool existe && existe;
    }

    private static async Task<VentaResponse> ObtenerVentaAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        int ventaId,
        CancellationToken cancellationToken)
    {
        const string sql = """
            SELECT ventaid, numerofactura, fechaventa, subtotal, iva, total, formapago, estado
            FROM public.ventas
            WHERE ventaid = @venta
            """;

        await using var command = new NpgsqlCommand(sql, connection, transaction);
        command.Parameters.Add(new NpgsqlParameter("venta", NpgsqlDbType.Integer) { Value = ventaId });
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        if (!await reader.ReadAsync(cancellationToken))
        {
            throw new DatabaseException($"No se pudo recuperar la venta {ventaId}.");
        }

        return new VentaResponse(
            reader.GetInt32(0),
            reader.GetString(1),
            reader.GetDateTime(2),
            reader.GetDecimal(3),
            reader.GetDecimal(4),
            reader.GetDecimal(5),
            reader.GetString(6),
            reader.GetString(7));
    }
}
