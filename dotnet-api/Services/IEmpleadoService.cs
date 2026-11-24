using Comisariato.Api.DTOs;

namespace Comisariato.Api.Services;

public interface IEmpleadoService
{
    Task<List<VentaEmpleadoResponse>> VentasAsync(int empleadoId, CancellationToken cancellationToken = default);
}