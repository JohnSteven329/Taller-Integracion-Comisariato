package edu.comisariato.api.repository;
import edu.comisariato.api.dto.VentaRequest;
import edu.comisariato.api.dto.VentaResponse;
import edu.comisariato.api.dto.VentaEmpleadoResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

@Repository
public class VentaRepository {

    private final JdbcTemplate jdbcTemplate;

    public VentaRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean existeEmpleado(Integer empleadoId) {

        String sql = """
            SELECT EXISTS (
                SELECT 1
                FROM public.empleados
                WHERE empleadoid = ?
            )
            """;

        return Boolean.TRUE.equals(
            jdbcTemplate.queryForObject(
                sql, Boolean.class, empleadoId
            )
        );
    }

    public List<VentaEmpleadoResponse> obtenerVentasPorEmpleado(
            Integer empleadoId) {

        String sql = """
            SELECT ventaid, numerofactura, fechaventa, total
            FROM public.fn_ventasporempleado(?)
            ORDER BY ventaid
            """;

        return jdbcTemplate.query(sql, (rs, rowNum) ->
            new VentaEmpleadoResponse(
                rs.getInt("ventaid"),
                rs.getString("numerofactura"),
                rs.getObject("fechaventa", LocalDateTime.class),
                rs.getBigDecimal("total")
            ),
            empleadoId
        );
    }
    public Integer registrarVenta(VentaRequest request) {

    String sql = """
        CALL public.usp_registrarventa(
            ?, ?, ?, ?, ?, ?, NULL::INTEGER
        )
        """;

    return jdbcTemplate.queryForObject(
        sql,
        Integer.class,
        request.numeroFactura(),
        request.clienteId(),
        request.empleadoId(),
        request.formaPago(),
        request.productoId(),
        request.cantidad()
        );
    }

    public VentaResponse obtenerVenta(Integer ventaId) {

        String sql = """
        SELECT ventaid, numerofactura,
               subtotal, iva, total, estado
        FROM public.ventas
        WHERE ventaid = ?
        """;

            return jdbcTemplate.queryForObject(
                sql,
            (   rs, rowNum) -> new VentaResponse(
                rs.getInt("ventaid"),
                rs.getString("numerofactura"),
                rs.getBigDecimal("subtotal"),
                rs.getBigDecimal("iva"),
                rs.getBigDecimal("total"),
                rs.getString("estado")
                ),
                ventaId
            );
        }
        public void anularVenta(Integer ventaId, Integer empleadoId) {

        String sql = """
        CALL public.usp_anularventa(?, ?)
        """;

        jdbcTemplate.update(sql, ventaId, empleadoId);
    }
}