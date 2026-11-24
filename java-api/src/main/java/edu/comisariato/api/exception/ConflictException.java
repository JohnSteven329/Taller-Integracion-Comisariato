package edu.comisariato.api.exception;

public class ConflictException extends RuntimeException {

    public ConflictException(String mensaje, Throwable causa) {
        super(mensaje, causa);
    }
}