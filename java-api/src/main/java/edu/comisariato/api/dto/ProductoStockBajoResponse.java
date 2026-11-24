package edu.comisariato.api.dto;

public record ProductoStockBajoResponse(
    Integer productoId,
    String nombre,
    Integer stock,
    Integer stockMinimo,
    String categoria
) {
}