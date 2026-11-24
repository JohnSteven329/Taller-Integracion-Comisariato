package edu.comisariato.api.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record AnularVentaRequest(

    @NotNull(message = "El empleado es obligatorio")
    @Positive(message = "El ID del empleado debe ser positivo")
    Integer empleadoId

) {
}