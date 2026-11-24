using Comisariato.Api.DTOs;
using Comisariato.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Comisariato.Api.Controllers;

[ApiController]
[Route("api/ventas")]
[Tags("Ventas")]
public sealed class VentasController : ControllerBase
{
    private readonly IVentaService _ventaService;

    public VentasController(IVentaService ventaService)
    {
        _ventaService = ventaService;
    }

    /// <summary>Registra una venta. El total lo calcula exclusivamente el SP.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(VentaResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status422UnprocessableEntity)]
    public async Task<ActionResult<VentaResponse>> Registrar(
        [FromBody] VentaRequest request,
        CancellationToken cancellationToken)
    {
        var venta = await _ventaService.RegistrarAsync(request, cancellationToken);
        return Created($"/api/ventas/{venta.VentaId}", venta);
    }

    /// <summary>Anula una venta en estado Completada.</summary>
    [HttpPost("{ventaId:int}/anular")]
    [ProducesResponseType(typeof(VentaResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status409Conflict)]
    public async Task<ActionResult<VentaResponse>> Anular(
        [FromRoute] int ventaId,
        CancellationToken cancellationToken)
    {
        var venta = await _ventaService.AnularAsync(ventaId, cancellationToken);
        return Ok(venta);
    }
}