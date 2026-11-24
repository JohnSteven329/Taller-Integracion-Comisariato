using Comisariato.Api.DTOs;

namespace Comisariato.Api.Repositories;

public interface IEmpleadoRepository
{
    Task<bool> ExisteAsync(int empleadoId, CancellationToken cancellationToken = default);

    Task<List<VentaEmpleadoResponse>> VentasAsync(int empleadoId, CancellationToken cancellationToken = default);
}