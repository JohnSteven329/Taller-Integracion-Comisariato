using Comisariato.Api.DTOs;
using Comisariato.Api.Infrastructure;
using Comisariato.Api.Repositories;

namespace Comisariato.Api.Services;

public sealed class EmpleadoService : IEmpleadoService
{
    private readonly IEmpleadoRepository _empleadoRepository;
    private readonly ILogger<EmpleadoService> _logger;

    public EmpleadoService(IEmpleadoRepository empleadoRepository, ILogger<EmpleadoService> logger)
    {
        _empleadoRepository = empleadoRepository;
        _logger = logger;
    }

    public async Task<List<VentaEmpleadoResponse>> VentasAsync(
        int empleadoId,
        CancellationToken cancellationToken = default)
    {
        if (!await _empleadoRepository.ExisteAsync(empleadoId, cancellationToken))
        {
            throw new NotFoundException($"El empleado {empleadoId} no existe.");
        }

        var ventas = await _empleadoRepository.VentasAsync(empleadoId, cancellationToken);
        _logger.LogInformation(
            "Consulta de ventas empleado={EmpleadoId}: {Cantidad} venta(s)",
            empleadoId, ventas.Count);
        return ventas;
    }
}