namespace Comisariato.Api.DTOs;

public record ProductoStockBajoResponse(
    int ProductoId,
    string Nombre,
    int Stock,
    int StockMinimo,
    string Categoria
);
