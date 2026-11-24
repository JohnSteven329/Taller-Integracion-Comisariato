namespace Comisariato.Api.DTOs;

public record VentaEmpleadoResponse(
    int VentaId,
    string NumeroFactura,
    DateTime FechaVenta,
    decimal Total
);
