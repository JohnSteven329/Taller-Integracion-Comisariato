package edu.comisariato.api.controller;

import edu.comisariato.api.dto.ProductoStockBajoResponse;
import edu.comisariato.api.service.ProductoService;
import edu.comisariato.api.dto.MovimientoInventarioResponse;
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
@RequestMapping("/api/productos")
@Tag(name = "Productos", description = "Operaciones de inventario")
public class ProductoController {

    private final ProductoService productoService;

    public ProductoController(ProductoService productoService) {
        this.productoService = productoService;
    }

    @GetMapping("/stock-bajo")
    @Operation(summary = "Consultar productos con stock bajo",
        description = "Devuelve los productos con stock bajo; puede devolver una lista vacía.")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Consulta exitosa",
            content = @Content(mediaType = "application/json",
                array = @ArraySchema(schema = @Schema(implementation = ProductoStockBajoResponse.class)))),
        @ApiResponse(responseCode = "500", description = "Error interno del servidor",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class)))
    })
    public ResponseEntity<List<ProductoStockBajoResponse>> obtenerStockBajo() {

        return ResponseEntity.ok(
            productoService.obtenerStockBajo()
        );
    }

    @GetMapping("/{productoId}/movimientos")
    @Operation(summary = "Consultar movimientos de inventario por producto",
        description = "Devuelve los movimientos asociados al ID; puede devolver una lista vacía.")
    @ApiResponses({
        @ApiResponse(responseCode = "200", description = "Consulta exitosa",
            content = @Content(mediaType = "application/json",
                array = @ArraySchema(schema = @Schema(implementation = MovimientoInventarioResponse.class)))),
        @ApiResponse(responseCode = "400", description = "Datos de entrada inválidos",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class))),
        @ApiResponse(responseCode = "500", description = "Error interno del servidor",
            content = @Content(mediaType = "application/problem+json",
                schema = @Schema(implementation = ProblemDetail.class)))
    })
    public ResponseEntity<List<MovimientoInventarioResponse>>
        obtenerMovimientos(@PathVariable("productoId") Integer productoId) {

        return ResponseEntity.ok(
            productoService.obtenerMovimientos(productoId)
        );
    }
}
