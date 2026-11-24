package edu.comisariato.api.repository;
import edu.comisariato.api.dto.MovimientoInventarioResponse;
import edu.comisariato.api.dto.ProductoStockBajoResponse;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class ProductoRepository {

    private final JdbcTemplate jdbcTemplate;

    public ProductoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<ProductoStockBajoResponse> obtenerStockBajo() {

        String sql = """
            SELECT productoid, nombre, stock,
                   stockminimo, categoria
            FROM public.vw_productosstockbajo
            ORDER BY productoid
            """;

        return jdbcTemplate.query(sql, (rs, rowNum) ->
            new ProductoStockBajoResponse(
                rs.getInt("productoid"),
                rs.getString("nombre"),
                rs.getInt("stock"),
                rs.getInt("stockminimo"),
                rs.getString("categoria")
            )
        );
    }
    public List<MovimientoInventarioResponse> obtenerMovimientos(
        Integer productoId) {

    String sql = """
        SELECT movimientoid,
               productoid,
               tipomovimiento,
               cantidad,
               stockanterior,
               stocknuevo,
               referenciatipo,
               referenciaid,
               fechamovimiento,
               empleadoid
        FROM public.movimientosinventario
        WHERE productoid = ?
        ORDER BY movimientoid
        """;

    return jdbcTemplate.query(sql, (rs, rowNum) ->
        new MovimientoInventarioResponse(
            rs.getLong("movimientoid"),
            rs.getInt("productoid"),
            rs.getString("tipomovimiento"),
            rs.getInt("cantidad"),
            rs.getInt("stockanterior"),
            rs.getInt("stocknuevo"),
            rs.getString("referenciatipo"),
            rs.getObject("referenciaid", Integer.class),
            rs.getTimestamp("fechamovimiento").toLocalDateTime(),
            rs.getObject("empleadoid", Integer.class)
            ),
            productoId
        );
    }
}