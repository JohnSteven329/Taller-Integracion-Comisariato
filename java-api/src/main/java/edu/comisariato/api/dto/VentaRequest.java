package edu.comisariato.api.dto;

import jakarta.validation.constraints.*;

public record VentaRequest(

    @NotBlank(message = "El número de factura es obligatorio")
    @Size(max = 20)
    String numeroFactura,

    @NotNull(message = "El cliente es obligatorio")
    @Positive
    Integer clienteId,

    @NotNull(message = "El empleado es obligatorio")
    @Positive
    Integer empleadoId,

    @NotBlank(message = "La forma de pago es obligatoria")
    @Size(max = 30)
    String formaPago,

    @NotNull(message = "El producto es obligatorio")
    @Positive
    Integer productoId,

    @NotNull(message = "La cantidad es obligatoria")
    @Positive(message = "La cantidad debe ser mayor a cero")
    Integer cantidad

) {
}