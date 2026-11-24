package edu.comisariato.api.controller;

import edu.comisariato.api.dto.VentaRequest;
import edu.comisariato.api.dto.VentaResponse;
import edu.comisariato.api.service.VentaService;
import edu.comisariato.api.service.DeadlockRetry;
import edu.comisariato.api.dto.AnularVentaRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/ventas")
@Tag(name = "Ventas", description = "Gestión de ventas")
public class VentaController {

    private final VentaService ventaService;
    private final DeadlockRetry deadlockRetry;

    public VentaController(VentaService ventaService,
                           DeadlockRetry deadlockRetry) {
        this.ventaService = ventaService;
        this.deadlockRetry = deadlockRetry;
    }

    @PostMapping
    @Operation(summary = "Registrar una nueva venta",
        description = "Registra la venta y actualiza el inventario. Reintenta una vez ante SQLSTATE 40P01.")
    @ApiResponses({
        @ApiResponse(responseCode = "201", description = "Venta registrada correctamente",
            content = @Content(mediaType = "application/json",
                schema = @Schema(implementation = VentaResponse.class))),
        @ApiResponse(responseCode = "400", description = "Datos de entrada inválidos",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "409", description = "Número de factura duplicado",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "422", description = "Stock insuficiente",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "500", description = "Error interno del servidor",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class)))
    })
    public ResponseEntity<VentaResponse> registrarVenta(
            @Valid @RequestBody VentaRequest request) {

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(deadlockRetry.ejecutar(
                () -> ventaService.registrarVenta(request)
            ));
    }

    @PostMapping("/{ventaId}/anular")
    @Operation(summary = "Anular una venta existente",
        description = "Anula la venta y devuelve las unidades al inventario. Reintenta una vez ante SQLSTATE 40P01.")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Venta anulada correctamente",
            content = @Content(mediaType = "application/json",
                schema = @Schema(implementation = VentaResponse.class))),
        @ApiResponse(responseCode = "400", description = "Datos de entrada inválidos",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "404", description = "Venta no encontrada",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "409", description = "La venta no se encuentra en estado Completada",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "500", description = "Error interno del servidor",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class)))
    })
    public ResponseEntity<VentaResponse> anularVenta(
        @PathVariable("ventaId") Integer ventaId,
        @Valid @RequestBody AnularVentaRequest request) {

        return ResponseEntity.ok(
            deadlockRetry.ejecutar(
                () -> ventaService.anularVenta(ventaId, request.empleadoId())
            )
        );
    }
}
