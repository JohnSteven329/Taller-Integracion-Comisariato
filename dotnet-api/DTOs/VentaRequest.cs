using System.ComponentModel.DataAnnotations;

namespace Comisariato.Api.DTOs;

/// <summary>Request para POST /api/ventas. El total lo calcula el procedimiento almacenado.</summary>
public record VentaRequest(
    [param: Required(ErrorMessage = "numeroFactura es obligatorio")]
    [param: StringLength(20, MinimumLength = 1, ErrorMessage = "numeroFactura admite de 1 a 20 caracteres")]
    string? NumeroFactura,

    [param: Range(1, int.MaxValue, ErrorMessage = "clienteId debe ser positivo")]
    int? ClienteId,

    [param: Required(ErrorMessage = "empleadoId es obligatorio")]
    [param: Range(1, int.MaxValue, ErrorMessage = "empleadoId debe ser positivo")]
    int? EmpleadoId,

    [param: Required(ErrorMessage = "formaPago es obligatoria")]
    [param: RegularExpression("^(Efectivo|Tarjeta|Transferencia)$",
        ErrorMessage = "formaPago debe ser Efectivo, Tarjeta o Transferencia")]
    string? FormaPago,

    [param: Required(ErrorMessage = "productoId es obligatorio")]
    [param: Range(1, int.MaxValue, ErrorMessage = "productoId debe ser positivo")]
    int? ProductoId,

    [param: Required(ErrorMessage = "cantidad es obligatoria")]
    [param: Range(1, int.MaxValue, ErrorMessage = "cantidad debe ser mayor que cero")]
    int? Cantidad
);
