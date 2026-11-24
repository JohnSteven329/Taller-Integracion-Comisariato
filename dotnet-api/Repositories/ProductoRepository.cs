using Comisariato.Api.DTOs;
using Npgsql;

namespace Comisariato.Api.Repositories;

public sealed class ProductoRepository : IProductoRepository
{
    private readonly NpgsqlDataSource _dataSource;

    public ProductoRepository(NpgsqlDataSource dataSource)
    {
        _dataSource = dataSource;
    }

    public async Task<List<ProductoStockBajoResponse>> StockBajoAsync(
        CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT productoid, nombre, stock, stockminimo, categoria
            FROM public.vw_productosstockbajo
            ORDER BY stock ASC, nombre ASC
            """;

        await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var productos = new List<ProductoStockBajoResponse>();
        while (await reader.ReadAsync(cancellationToken))
        {
            productos.Add(new ProductoStockBajoResponse(
                reader.GetInt32(0),
                reader.GetString(1),
                reader.GetInt32(2),
                reader.GetInt32(3),
                reader.GetString(4)));
        }

        return productos;
    }

    public async Task<List<MovimientoResponse>> MovimientosAsync(
        int productoId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
            SELECT movimientoid, productoid, tipomovimiento, cantidad,
                   stockanterior, stocknuevo, referenciatipo, referenciaid,
                   fechamovimiento, empleadoid
            FROM movimientosinventario
            WHERE productoid = @producto
            ORDER BY fechamovimiento DESC, movimientoid DESC
            """;

        await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("producto", productoId);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var movimientos = new List<MovimientoResponse>();
        while (await reader.ReadAsync(cancellationToken))
        {
            movimientos.Add(new MovimientoResponse(
                reader.GetInt64(0),
                reader.GetInt32(1),
                reader.GetString(2),
                reader.GetInt32(3),
                reader.GetInt32(4),
                reader.GetInt32(5),
                reader.IsDBNull(6) ? null : reader.GetString(6),
                reader.IsDBNull(7) ? null : reader.GetInt32(7),
                reader.GetDateTime(8),
                reader.IsDBNull(9) ? null : reader.GetInt32(9)));
        }

        return movimientos;
    }

    public async Task<bool> ExisteAsync(int productoId, CancellationToken cancellationToken = default)
    {
        const string sql = "SELECT EXISTS (SELECT 1 FROM productos WHERE productoid = @producto)";

        await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);
        await using var command = new NpgsqlCommand(sql, connection);
        command.Parameters.AddWithValue("producto", productoId);
        var result = await command.ExecuteScalarAsync(cancellationToken);
        return result is bool exists && exists;
    }
}