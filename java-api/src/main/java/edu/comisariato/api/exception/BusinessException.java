package edu.comisariato.api.exception;

public class BusinessException extends RuntimeException {

    public BusinessException(String mensaje, Throwable causa) {
        super(mensaje, causa);
    }
}