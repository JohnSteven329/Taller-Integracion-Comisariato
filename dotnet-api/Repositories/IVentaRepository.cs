using Comisariato.Api.DTOs;
using Npgsql;

namespace Comisariato.Api.Repositories;

public interface IVentaRepository
{
    Task<VentaResponse> RegistrarAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        VentaRequest request,
        CancellationToken cancellationToken = default);

    Task<VentaResponse> AnularAsync(
        NpgsqlConnection connection,
        NpgsqlTransaction transaction,
        int ventaId,
        CancellationToken cancellationToken = default);
}