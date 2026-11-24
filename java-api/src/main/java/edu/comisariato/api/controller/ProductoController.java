package edu.comisariato.api.controller;

import edu.comisariato.api.dto.ProductoStockBajoResponse;
import edu.comisariato.api.service.ProductoService;
import edu.comisariato.api.dto.MovimientoInventarioResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/productos")
@Tag(name = "Productos", description = "Operaciones de inventario")
public class ProductoController {

    private final ProductoService productoService;

    public ProductoController(ProductoService productoService) {
        this.productoService = productoService;
    }

    @GetMapping("/stock-bajo")
    @Operation(summary = "Consultar productos con stock bajo")
    public ResponseEntity<List<ProductoStockBajoResponse>> obtenerStockBajo() {

        return ResponseEntity.ok(
            productoService.obtenerStockBajo()
        );
    }
    
    @GetMapping("/{productoId}/movimientos")
    @Operation(summary = "Consultar movimientos de inventario por producto")
    public ResponseEntity<List<MovimientoInventarioResponse>>
        obtenerMovimientos(@PathVariable("productoId") Integer productoId) {

        return ResponseEntity.ok(
        productoService.obtenerMovimientos(productoId)
        );
    }
}