package edu.comisariato.api.service;

import edu.comisariato.api.dto.ProductoStockBajoResponse;
import edu.comisariato.api.repository.ProductoRepository;
import edu.comisariato.api.dto.MovimientoInventarioResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ProductoService {

    private static final Logger logger =
        LoggerFactory.getLogger(ProductoService.class);

    private final ProductoRepository productoRepository;

    public ProductoService(ProductoRepository productoRepository) {
        this.productoRepository = productoRepository;
    }

    @Transactional(readOnly = true)
    public List<ProductoStockBajoResponse> obtenerStockBajo() {

        List<ProductoStockBajoResponse> productos =
            productoRepository.obtenerStockBajo();

        logger.info(
            "Consulta de stock bajo exitosa. Productos encontrados: {}",
            productos.size()
        );

        return productos;
    }
    @Transactional(readOnly = true)
    public List<MovimientoInventarioResponse> obtenerMovimientos(
        Integer productoId) {

        List<MovimientoInventarioResponse> movimientos =
        productoRepository.obtenerMovimientos(productoId);

        logger.info(
        "Consulta de movimientos del producto {}. Registros: {}",
        productoId,
        movimientos.size()
        );
        return movimientos;
    }
}