namespace Comisariato.Api.DTOs;

public record VentaResponse(
    int VentaId,
    string NumeroFactura,
    DateTime FechaVenta,
    decimal Subtotal,
    decimal Iva,
    decimal Total,
    string FormaPago,
    string Estado
);