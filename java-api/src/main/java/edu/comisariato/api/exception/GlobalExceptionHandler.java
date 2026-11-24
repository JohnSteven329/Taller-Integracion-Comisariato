package edu.comisariato.api.exception;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;

import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler
        extends ResponseEntityExceptionHandler {

    private static final Logger logger =
        LoggerFactory.getLogger(GlobalExceptionHandler.class);

    // HTTP 400: validación de campos

    @Override
    protected ResponseEntity<Object> handleMethodArgumentNotValid(
            MethodArgumentNotValidException ex,
            HttpHeaders headers,
            HttpStatusCode status,
            WebRequest request) {

        Map<String, String> errores = new LinkedHashMap<>();

        ex.getBindingResult().getFieldErrors().forEach(error ->
            errores.putIfAbsent(
                error.getField(),
                error.getDefaultMessage()
            )
        );

        ProblemDetail problema = ProblemDetail.forStatusAndDetail(
            HttpStatus.BAD_REQUEST,
            "Existen campos invalidos o faltantes"
        );

        problema.setTitle("Error de validacion");
        problema.setProperty("errores", errores);

        return handleExceptionInternal(
            ex, problema, headers, status, request
        );
    }

    // HTTP 404: recurso inexistente

    @ExceptionHandler(NotFoundException.class)
    public ProblemDetail manejarNotFound(NotFoundException ex) {

        logger.error("Recurso no encontrado: {}", ex.getMessage(), ex);

        ProblemDetail problema = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND,
            ex.getMessage()
        );

        problema.setTitle("Recurso no encontrado");

        return problema;
    }

    // HTTP 409: conflicto

    @ExceptionHandler(ConflictException.class)
    public ProblemDetail manejarConflicto(ConflictException ex) {

        logger.error("Conflicto: {}", ex.getMessage(), ex);

        ProblemDetail problema = ProblemDetail.forStatusAndDetail(
            HttpStatus.CONFLICT,
            ex.getMessage()
        );

        problema.setTitle("Conflicto");

        return problema;
    }

    // HTTP 422: regla de negocio

    @ExceptionHandler(BusinessException.class)
    public ProblemDetail manejarNegocio(BusinessException ex) {

        logger.error("Regla de negocio: {}", ex.getMessage(), ex);

        ProblemDetail problema = ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_ENTITY,
            ex.getMessage()
        );

        problema.setTitle("Regla de negocio incumplida");

        return problema;
    }

    // Errores gestionados por Spring MVC

    @Override
    protected ResponseEntity<Object> handleExceptionInternal(
            Exception ex,
            Object body,
            HttpHeaders headers,
            HttpStatusCode statusCode,
            WebRequest request) {

        logger.error(
            "Error HTTP {}: {}",
            statusCode.value(),
            ex.getMessage(),
            ex
        );

        return super.handleExceptionInternal(
            ex, body, headers, statusCode, request
        );
    }

    // HTTP 500: errores inesperados

    @ExceptionHandler(Exception.class)
    public ProblemDetail manejarErrorGeneral(Exception ex) {

        logger.error("Error interno de la API", ex);

        ProblemDetail problema = ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "Ocurrio un error inesperado en el servidor"
        );

        problema.setTitle("Error interno del servidor");

        return problema;
    }
}