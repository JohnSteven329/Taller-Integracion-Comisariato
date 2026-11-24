using Comisariato.Api.DTOs;
using Comisariato.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Comisariato.Api.Controllers;

[ApiController]
[Route("api/productos")]
[Tags("Productos")]
public sealed class ProductosController : ControllerBase
{
    private readonly IProductoService _productoService;

    public ProductosController(IProductoService productoService)
    {
        _productoService = productoService;
    }

    /// <summary>Productos cuyo stock está en o por debajo del mínimo.</summary>
    [HttpGet("stock-bajo")]
    [ProducesResponseType(typeof(List<ProductoStockBajoResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<List<ProductoStockBajoResponse>>> StockBajo(
        CancellationToken cancellationToken)
    {
        return Ok(await _productoService.StockBajoAsync(cancellationToken));
    }

    /// <summary>Movimientos de inventario de un producto.</summary>
    [HttpGet("{productoId:int}/movimientos")]
    [ProducesResponseType(typeof(List<MovimientoResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<List<MovimientoResponse>>> Movimientos(
        [FromRoute] int productoId,
        CancellationToken cancellationToken)
    {
        return Ok(await _productoService.MovimientosAsync(productoId, cancellationToken));
    }
}