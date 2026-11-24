using Comisariato.Api.DTOs;
using Comisariato.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Comisariato.Api.Controllers;

[ApiController]
[Route("api/empleados")]
[Tags("Empleados")]
public sealed class EmpleadosController : ControllerBase
{
    private readonly IEmpleadoService _empleadoService;

    public EmpleadosController(IEmpleadoService empleadoService)
    {
        _empleadoService = empleadoService;
    }

    /// <summary>Ventas de un empleado. 404 si no existe; [] si no tiene ventas.</summary>
    [HttpGet("{empleadoId:int}/ventas")]
    [ProducesResponseType(typeof(List<VentaEmpleadoResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<List<VentaEmpleadoResponse>>> Ventas(
        [FromRoute] int empleadoId,
        CancellationToken cancellationToken)
    {
        return Ok(await _empleadoService.VentasAsync(empleadoId, cancellationToken));
    }
}