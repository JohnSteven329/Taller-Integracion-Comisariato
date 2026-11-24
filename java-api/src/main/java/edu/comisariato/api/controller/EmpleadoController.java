package edu.comisariato.api.controller;

import edu.comisariato.api.dto.VentaEmpleadoResponse;
import edu.comisariato.api.service.VentaService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

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
    @Operation(summary = "Consultar ventas por empleado")
    public ResponseEntity<List<VentaEmpleadoResponse>>
            obtenerVentasPorEmpleado(
                @PathVariable("empleadoId") Integer empleadoId) {

        return ResponseEntity.ok(
            ventaService.obtenerVentasPorEmpleado(empleadoId)
        );
    }
}