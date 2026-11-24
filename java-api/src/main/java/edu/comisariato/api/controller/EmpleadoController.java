package edu.comisariato.api.controller;

import edu.comisariato.api.dto.VentaEmpleadoResponse;
import edu.comisariato.api.service.VentaService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.ArraySchema;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/empleados")
@Tag(name = "Empleados", description = "Consulta de ventas por empleado")
public class EmpleadoController {

    private final VentaService ventaService;

    public EmpleadoController(VentaService ventaService) {
        this.ventaService = ventaService;
    }

    @GetMapping("/{empleadoId}/ventas")
    @Operation(summary = "Consultar ventas por empleado",
        description = "Devuelve las ventas del empleado; una lista vacía si no tiene ventas.")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Consulta exitosa",
            content = @Content(mediaType = "application/json",
                array = @ArraySchema(schema = @Schema(implementation = VentaEmpleadoResponse.class)))),
        @ApiResponse(responseCode = "400", description = "Datos de entrada inválidos",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "404", description = "Empleado no encontrado",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "500", description = "Error interno del servidor",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class)))
    })
    public ResponseEntity<List<VentaEmpleadoResponse>>
            obtenerVentasPorEmpleado(
                @PathVariable("empleadoId") Integer empleadoId) {

        return ResponseEntity.ok(
            ventaService.obtenerVentasPorEmpleado(empleadoId)
        );
    }
}
