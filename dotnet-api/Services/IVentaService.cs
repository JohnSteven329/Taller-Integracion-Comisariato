using Comisariato.Api.DTOs;

namespace Comisariato.Api.Services;

public interface IVentaService
{
    Task<VentaResponse> RegistrarAsync(VentaRequest request, CancellationToken cancellationToken = default);

    Task<VentaResponse> AnularAsync(int ventaId, CancellationToken cancellationToken = default);
}