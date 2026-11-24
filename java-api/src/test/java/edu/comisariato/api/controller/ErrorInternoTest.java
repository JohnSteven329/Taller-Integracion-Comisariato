package edu.comisariato.api.controller;

import edu.comisariato.api.exception.GlobalExceptionHandler;
import edu.comisariato.api.service.DeadlockRetry;
import edu.comisariato.api.service.VentaService;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class ErrorInternoTest {

    @Test
    void errorInesperadoDevuelve500() throws Exception {

        VentaService service = mock(VentaService.class);

        when(service.registrarVenta(any()))
            .thenThrow(new RuntimeException(
                "Error interno simulado"
            ));

        MockMvc mvc = MockMvcBuilders
            .standaloneSetup(
                new VentaController(service, new DeadlockRetry())
            )
            .setControllerAdvice(new GlobalExceptionHandler())
            .build();

        mvc.perform(post("/api/ventas")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {
                    "numeroFactura": "TEST-500",
                    "clienteId": 1,
                    "empleadoId": 1,
                    "formaPago": "Efectivo",
                    "productoId": 1,
                    "cantidad": 1
                }
                """))
            .andExpect(status().isInternalServerError())
            .andExpect(content().contentTypeCompatibleWith(
                MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(jsonPath("$.status").value(500))
            .andExpect(jsonPath("$.title")
                .value("Error interno del servidor"))
            .andExpect(jsonPath("$.detail")
                .value("Ocurrio un error inesperado en el servidor"));

        verify(service, times(1)).registrarVenta(any());
    }
}