using Comisariato.Api.DTOs;
using Comisariato.Api.Infrastructure;
using Comisariato.Api.Repositories;

namespace Comisariato.Api.Services;

public sealed class ProductoService : IProductoService
{
    private readonly IProductoRepository _productoRepository;
    private readonly ILogger<ProductoService> _logger;

    public ProductoService(IProductoRepository productoRepository, ILogger<ProductoService> logger)
    {
        _productoRepository = productoRepository;
        _logger = logger;
    }

    public async Task<List<ProductoStockBajoResponse>> StockBajoAsync(
        CancellationToken cancellationToken = default)
    {
        var productos = await _productoRepository.StockBajoAsync(cancellationToken);
        _logger.LogInformation("Consulta de stock bajo: {Cantidad} producto(s)", productos.Count);
        return productos;
    }

    public async Task<List<MovimientoResponse>> MovimientosAsync(
        int productoId,
        CancellationToken cancellationToken = default)
    {
        if (!await _productoRepository.ExisteAsync(productoId, cancellationToken))
        {
            throw new NotFoundException($"El producto {productoId} no existe.");
        }

        var movimientos = await _productoRepository.MovimientosAsync(productoId, cancellationToken);
        _logger.LogInformation(
            "Consulta de movimientos producto={ProductoId}: {Cantidad} registro(s)",
            productoId, movimientos.Count);
        return movimientos;
    }
}