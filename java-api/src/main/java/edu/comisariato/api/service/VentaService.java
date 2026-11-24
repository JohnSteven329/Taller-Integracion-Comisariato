package edu.comisariato.api.service;

import edu.comisariato.api.dto.VentaEmpleadoResponse;
import edu.comisariato.api.dto.VentaRequest;
import edu.comisariato.api.dto.VentaResponse;

import edu.comisariato.api.exception.NotFoundException;
import edu.comisariato.api.exception.ConflictException;
import edu.comisariato.api.exception.BusinessException;

import edu.comisariato.api.repository.VentaRepository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.SQLException;
import java.text.Normalizer;
import java.util.Locale;
import java.util.List;

@Service
public class VentaService {

    private static final Logger logger =
        LoggerFactory.getLogger(VentaService.class);

    private final VentaRepository ventaRepository;

    public VentaService(VentaRepository ventaRepository) {
        this.ventaRepository = ventaRepository;
    }

    @Transactional(readOnly = true)
    public List<VentaEmpleadoResponse> obtenerVentasPorEmpleado(
            Integer empleadoId) {

        if (!ventaRepository.existeEmpleado(empleadoId)) {
            throw new NotFoundException(
                "El empleado " + empleadoId + " no existe"
            );
        }

        List<VentaEmpleadoResponse> ventas =
            ventaRepository.obtenerVentasPorEmpleado(empleadoId);

        logger.info(
            "Consulta de ventas del empleado {}. Registros: {}",
            empleadoId,
            ventas.size()
        );

        return ventas;
    }

    @Transactional
    public VentaResponse registrarVenta(VentaRequest request) {

        try {
            Integer ventaId =
                ventaRepository.registrarVenta(request);

            VentaResponse venta =
                ventaRepository.obtenerVenta(ventaId);

            logger.info(
                "Registro de venta ejecutado. ID: {}, Factura: {}, Total: {}",
                venta.ventaId(),
                venta.numeroFactura(),
                venta.total()
            );

            return venta;

        } catch (DataAccessException ex) {
            // Conservar el SQLSTATE para reintentar fuera de la transaccion.
            if (DeadlockRetry.esDeadlock(ex)) {
                throw ex;
            }
            throw traducirError(ex);
        }
    }

    @Transactional
    public VentaResponse anularVenta(
            Integer ventaId, Integer empleadoId) {

        try {
            ventaRepository.anularVenta(ventaId, empleadoId);

            VentaResponse venta =
                ventaRepository.obtenerVenta(ventaId);

            logger.info(
                "Venta anulada. ID: {}, Empleado: {}, Estado: {}",
                ventaId,
                empleadoId,
                venta.estado()
            );

            return venta;

        } catch (DataAccessException ex) {
            // Conservar el SQLSTATE para reintentar fuera de la transaccion.
            if (DeadlockRetry.esDeadlock(ex)) {
                throw ex;
            }
            throw traducirError(ex);
        }
    }

    private RuntimeException traducirError(
            DataAccessException ex) {

        Throwable causa = ex;

        while (causa != null) {

            if (causa instanceof SQLException sqlEx) {

                String estado = sqlEx.getSQLState();

                String mensaje = Normalizer.normalize(
                    String.valueOf(sqlEx.getMessage()),
                    Normalizer.Form.NFD
                ).replaceAll("\\p{M}", "")
                 .toLowerCase(Locale.ROOT);

                if ("23505".equals(estado)
                    && mensaje.contains("uq_ventas_numerofactura")) {

                    return new ConflictException(
                        "El numero de factura ya existe", ex
                    );
                }

                if ("P0001".equals(estado)) {

                    if (mensaje.contains("stock insuficiente")) {
                        return new BusinessException(
                            "Stock insuficiente para la venta", ex
                        );
                    }

                    if (mensaje.contains("la venta no existe")) {
                        return new NotFoundException(
                            "La venta no existe", ex
                        );
                    }

                    if (mensaje.contains(
                            "la venta no esta en estado completada")) {

                        return new ConflictException(
                            "La venta no se encuentra en estado Completada",
                            ex
                        );
                    }
                }
            }

            causa = causa.getCause();
        }

        return ex;
    }
}
