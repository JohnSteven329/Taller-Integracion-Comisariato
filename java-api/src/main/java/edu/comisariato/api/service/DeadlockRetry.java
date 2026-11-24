package edu.comisariato.api.service;

import java.sql.SQLException;
import java.util.function.Supplier;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class DeadlockRetry {

    private static final Logger logger =
            LoggerFactory.getLogger(DeadlockRetry.class);

    private static final int MAX_INTENTOS = 2;
    private static final long ESPERA_MS = 1000;

    public <T> T ejecutar(Supplier<T> operacion) {

        for (int intento = 1; ; intento++) {

            try {
                return operacion.get();

            } catch (RuntimeException ex) {

                if (!esDeadlock(ex)) {
                    throw ex;
                }

                logger.error(
                    "Deadlock detectado. SQLSTATE 40P01. Intento {}/{}",
                    intento, MAX_INTENTOS, ex
                );

                if (intento >= MAX_INTENTOS) {
                    throw ex;
                }

                try {
                    Thread.sleep(ESPERA_MS);

                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();

                    throw new IllegalStateException(
                        "Reintento interrumpido", e
                    );
                }

                logger.info(
                    "Reintentando operacion despues de 1000 ms"
                );
            }
        }
    }

    public static boolean esDeadlock(Throwable error) {

        Throwable causa = error;

        while (causa != null) {

            if (causa instanceof SQLException sqlException) {

                if ("40P01".equals(sqlException.getSQLState())) {
                    return true;
                }
            }

            causa = causa.getCause();
        }

        return false;
    }
}
