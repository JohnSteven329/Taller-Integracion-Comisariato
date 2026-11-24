package edu.comisariato.api.controller;

import java.math.BigDecimal;
import java.sql.SQLException;

import edu.comisariato.api.dto.AnularVentaRequest;
import edu.comisariato.api.dto.VentaRequest;
import edu.comisariato.api.dto.VentaResponse;
import edu.comisariato.api.service.DeadlockRetry;
import edu.comisariato.api.service.VentaService;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.http.HttpStatus;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class VentaControllerTest {
    private final VentaService service = mock(VentaService.class);
    private final VentaController controller = new VentaController(service, new DeadlockRetry());

    private RuntimeException deadlock() {
        return new DataAccessResourceFailureException("Deadlock simulado",
            new SQLException("Deadlock", "40P01"));
    }

    private VentaResponse respuesta(String estado) {
        return new VentaResponse(6, "JAVA-PRUEBA-001",
            new BigDecimal("2.20"), new BigDecimal("0.33"),
            new BigDecimal("2.53"), estado);
    }

    @Test
    void registroReintentaYDevuelve201() {
        VentaRequest request = new VentaRequest("JAVA-PRUEBA-001", 1, 1, "Efectivo", 1, 2);
        VentaResponse venta = respuesta("Completada");
        when(service.registrarVenta(request)).thenThrow(deadlock()).thenReturn(venta);
        var resultado = controller.registrarVenta(request);
        assertEquals(HttpStatus.CREATED, resultado.getStatusCode());
        assertEquals(venta, resultado.getBody());
        verify(service, times(2)).registrarVenta(request);
    }

    @Test
    void anulacionReintentaYDevuelve200() {
        VentaResponse venta = respuesta("Anulada");
        when(service.anularVenta(6, 1)).thenThrow(deadlock()).thenReturn(venta);
        var resultado = controller.anularVenta(6, new AnularVentaRequest(1));
        assertEquals(HttpStatus.OK, resultado.getStatusCode());
        assertEquals(venta, resultado.getBody());
        verify(service, times(2)).anularVenta(6, 1);
    }
}
