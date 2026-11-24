using System.Data;
using Comisariato.Api.DTOs;
using Comisariato.Api.Infrastructure;
using Comisariato.Api.Repositories;
using Npgsql;
using Polly.Retry;

namespace Comisariato.Api.Services;

public sealed class VentaService : IVentaService
{
    private readonly IVentaRepository _ventaRepository;
    private readonly NpgsqlDataSource _dataSource;
    private readonly ILogger<VentaService> _logger;
    private readonly AsyncRetryPolicy _deadlockPolicy;

    public VentaService(
        IVentaRepository ventaRepository,
        NpgsqlDataSource dataSource,
        ILogger<VentaService> logger)
    {
        _ventaRepository = ventaRepository;
        _dataSource = dataSource;
        _logger = logger;
        _deadlockPolicy = PollyPolicies.CreateDeadlockPolicy(logger);
    }

    public async Task<VentaResponse> RegistrarAsync(
        VentaRequest request,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "Registrando venta factura={Factura} empleado={Empleado} producto={Producto} cantidad={Cantidad}",
            request.NumeroFactura, request.EmpleadoId, request.ProductoId, request.Cantidad);

        try
        {
            var response = await ExecuteInTransactionAsync(
                (connection, transaction, token) =>
                    _ventaRepository.RegistrarAsync(connection, transaction, request, token),
                cancellationToken);

            _logger.LogInformation(
                "Venta registrada id={VentaId} factura={Factura} producto={Producto} subtotal={Subtotal} iva={Iva} total={Total}",
                response.VentaId, response.NumeroFactura, request.ProductoId,
                response.Subtotal, response.Iva, response.Total);

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error al registrar la venta factura={Factura} empleado={Empleado}",
                request.NumeroFactura, request.EmpleadoId);
            throw;
        }
    }

    public async Task<VentaResponse> AnularAsync(
        int ventaId,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Anulando venta id={VentaId}", ventaId);

        try
        {
            var response = await ExecuteInTransactionAsync(
                (connection, transaction, token) =>
                    _ventaRepository.AnularAsync(connection, transaction, ventaId, token),
                cancellationToken);

            _logger.LogInformation(
                "Venta anulada id={VentaId} factura={Factura} estado={Estado}",
                response.VentaId, response.NumeroFactura, response.Estado);

            return response;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error al anular la venta id={VentaId}", ventaId);
            throw;
        }
    }

    /// <summary>
    /// Abre conexión y transacción por cada intento. Polly reintenta la
    /// operación completa (incluida una transacción nueva) si hay deadlock.
    /// </summary>
    private async Task<T> ExecuteInTransactionAsync<T>(
        Func<NpgsqlConnection, NpgsqlTransaction, CancellationToken, Task<T>> operation,
        CancellationToken cancellationToken)
    {
        return await _deadlockPolicy.ExecuteAsync(async token =>
        {
            await using var connection = await _dataSource.OpenConnectionAsync(token);
            await using var transaction = await connection.BeginTransactionAsync(
                IsolationLevel.ReadCommitted, token);

            try
            {
                var result = await operation(connection, transaction, token);
                await transaction.CommitAsync(token);
                return result;
            }
            catch (Exception ex)
            {
                try
                {
                    await transaction.RollbackAsync(CancellationToken.None);
                }
                catch (Exception rollbackException)
                {
                    _logger.LogError(rollbackException, "Error al ejecutar ROLLBACK.");
                }

                if (ex is PostgresException postgresException)
                {
                    throw SqlErrorMapper.Map(postgresException, "transacción");
                }

                throw;
            }
        }, cancellationToken);
    }
}