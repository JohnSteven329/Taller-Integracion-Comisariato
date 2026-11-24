package edu.comisariato.api.dto;

import java.math.BigDecimal;

public record VentaResponse(
    Integer ventaId,
    String numeroFactura,
    BigDecimal subtotal,
    BigDecimal iva,
    BigDecimal total,
    String estado
) {
}