package edu.comisariato.api.service;

import java.sql.SQLException;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;

import static org.junit.jupiter.api.Assertions.*;

class DeadlockRetryTest {

    private final DeadlockRetry retry = new DeadlockRetry();

    private RuntimeException errorSql(String estado) {
        return new DataAccessResourceFailureException(
            "Error de prueba", new SQLException("Error SQL simulado", estado)
        );
    }

    @Test
    void operacionExitosaNoSeRepite() {
        AtomicInteger intentos = new AtomicInteger();
        String resultado = retry.ejecutar(() -> {
            intentos.incrementAndGet();
            return "OK";
        });
        assertEquals("OK", resultado);
        assertEquals(1, intentos.get());
    }

    @Test
    void deadlockSeReintentaUnaVezDespuesDeUnSegundo() {
        AtomicInteger intentos = new AtomicInteger();
        long inicio = System.nanoTime();
        String resultado = retry.ejecutar(() -> {
            if (intentos.incrementAndGet() == 1) {
                throw errorSql("40P01");
            }
            return "OK";
        });
        assertEquals("OK", resultado);
        assertEquals(2, intentos.get());
        assertTrue(System.nanoTime() - inicio >= 1_000_000_000L);
    }

    @Test
    void segundoDeadlockSePropagaSinTercerIntento() {
        AtomicInteger intentos = new AtomicInteger();
        RuntimeException error = errorSql("40P01");
        RuntimeException recibido = assertThrows(RuntimeException.class,
            () -> retry.ejecutar(() -> {
                intentos.incrementAndGet();
                throw error;
            })
        );
        assertSame(error, recibido);
        assertEquals(2, intentos.get());
    }

    @Test
    void facturaDuplicadaYReglaDeNegocioNoSeReintentan() {
        for (String estado : new String[]{"23505", "P0001"}) {
            AtomicInteger intentos = new AtomicInteger();
            RuntimeException error = errorSql(estado);
            RuntimeException recibido = assertThrows(RuntimeException.class,
                () -> retry.ejecutar(() -> {
                    intentos.incrementAndGet();
                    throw error;
                })
            );
            assertSame(error, recibido);
            assertEquals(1, intentos.get());
        }
    }

    @Test
    void interrupcionCancelaElReintentoYConservaLaSenal() {
        AtomicInteger intentos = new AtomicInteger();
        Thread.currentThread().interrupt();
        try {
            assertThrows(IllegalStateException.class, () -> retry.ejecutar(() -> {
                intentos.incrementAndGet();
                throw errorSql("40P01");
            }));
            assertEquals(1, intentos.get());
            assertTrue(Thread.currentThread().isInterrupted());
        } finally {
            Thread.interrupted();
        }
    }
}
