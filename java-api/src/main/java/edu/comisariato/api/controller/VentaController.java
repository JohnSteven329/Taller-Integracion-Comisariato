package edu.comisariato.api.controller;

import edu.comisariato.api.dto.VentaRequest;
import edu.comisariato.api.dto.VentaResponse;
import edu.comisariato.api.service.VentaService;
import edu.comisariato.api.service.DeadlockRetry;
import edu.comisariato.api.dto.AnularVentaRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
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
    @Operation(summary = "Registrar una nueva venta")
    public ResponseEntity<VentaResponse> registrarVenta(
            @Valid @RequestBody VentaRequest request) {

        return ResponseEntity
            .status(HttpStatus.CREATED)
            .body(deadlockRetry.ejecutar(
                () -> ventaService.registrarVenta(request)
            ));
    }
    
    @PostMapping("/{ventaId}/anular")
    @Operation(summary = "Anular una venta existente")
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
