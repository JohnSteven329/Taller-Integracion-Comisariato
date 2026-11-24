using Comisariato.Api.DTOs;

namespace Comisariato.Api.Services;

public interface IProductoService
{
    Task<List<ProductoStockBajoResponse>> StockBajoAsync(CancellationToken cancellationToken = default);

    Task<List<MovimientoResponse>> MovimientosAsync(int productoId, CancellationToken cancellationToken = default);
}