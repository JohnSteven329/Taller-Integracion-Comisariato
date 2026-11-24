using Npgsql;

namespace Comisariato.Api.Infrastructure;

/// <summary>Traduce los SQLSTATE del SP a excepciones de dominio.</summary>
public static class SqlErrorMapper
{
    public static Exception Map(PostgresException ex, string operation)
    {
        return ex.SqlState switch
        {
            "CS001" or "23505" => new ConflictException(
                "El NumeroFactura ya existe o viola una restricción de unicidad.", ex),
            "CS002" => new BusinessException(
                "Stock insuficiente para completar la venta.", ex),
            "CS003" => new NotFoundException(
                "La venta indicada no existe.", ex),
            "CS004" => new ConflictException(
                "La venta ya está anulada.", ex),
            "CS005" => new NotFoundException(
                "El producto indicado no existe o está inactivo.", ex),
            "CS006" => new NotFoundException(
                "El empleado indicado no existe o está inactivo.", ex),
            "CS007" => new BusinessException(
                "El cliente indicado no existe.", ex),
            "CS008" => new BadRequestException(
                "Los datos enviados no son válidos para la operación.", ex),
            "CS009" => new ConflictException(
                "La venta no se encuentra en un estado que permita anularla.", ex),
            "23503" => new BusinessException(
                "La operación referencia un registro inexistente.", ex),
            "23514" => new BusinessException(
                "La operación viola una regla de consistencia de la base de datos.", ex),
            "40P01" or "1205" or "40001" => new DeadlockException(
                "Deadlock o conflicto de serialización detectado.", ex),
            _ => new DatabaseException(
                $"Error de base de datos en {operation}: {ex.MessageText}", ex)
        };
    }
}