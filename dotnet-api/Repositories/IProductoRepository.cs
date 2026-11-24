using Comisariato.Api.DTOs;

namespace Comisariato.Api.Repositories;

public interface IProductoRepository
{
    Task<List<ProductoStockBajoResponse>> StockBajoAsync(CancellationToken cancellationToken = default);

    Task<List<MovimientoResponse>> MovimientosAsync(int productoId, CancellationToken cancellationToken = default);

    Task<bool> ExisteAsync(int productoId, CancellationToken cancellationToken = default);
}