package edu.comisariato.api.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record VentaEmpleadoResponse(
    Integer ventaId,
    String numeroFactura,
    LocalDateTime fechaVenta,
    BigDecimal total
) {
}