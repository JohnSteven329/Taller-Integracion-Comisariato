namespace Comisariato.Api.DTOs;

public record MovimientoResponse(
    long MovimientoId,
    int ProductoId,
    string TipoMovimiento,
    int Cantidad,
    int StockAnterior,
    int StockNuevo,
    string? ReferenciaTipo,
    int? ReferenciaId,
    DateTime FechaMovimiento,
    int? EmpleadoId
);