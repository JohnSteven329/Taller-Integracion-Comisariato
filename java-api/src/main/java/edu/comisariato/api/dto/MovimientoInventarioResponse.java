package edu.comisariato.api.dto;

import java.time.LocalDateTime;

public record MovimientoInventarioResponse(
    Long movimientoId,
    Integer productoId,
    String tipoMovimiento,
    Integer cantidad,
    Integer stockAnterior,
    Integer stockNuevo,
    String referenciaTipo,
    Integer referenciaId,
    LocalDateTime fechaMovimiento,
    Integer empleadoId
) {
}