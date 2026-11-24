namespace Comisariato.Api.Infrastructure;

/// <summary>Excepción de dominio con su código HTTP y título ProblemDetails.</summary>
public abstract class ApiException : Exception
{
    protected ApiException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public abstract int StatusCode { get; }
    public abstract string Title { get; }
}

public sealed class NotFoundException : ApiException
{
    public NotFoundException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public override int StatusCode => StatusCodes.Status404NotFound;
    public override string Title => "Recurso no encontrado";
}

public sealed class ConflictException : ApiException
{
    public ConflictException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public override int StatusCode => StatusCodes.Status409Conflict;
    public override string Title => "Conflicto de estado";
}

public sealed class BusinessException : ApiException
{
    public BusinessException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public override int StatusCode => StatusCodes.Status422UnprocessableEntity;
    public override string Title => "Regla de negocio violada";
}

public sealed class BadRequestException : ApiException
{
    public BadRequestException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public override int StatusCode => StatusCodes.Status400BadRequest;
    public override string Title => "Solicitud inválida";
}

public sealed class DeadlockException : ApiException
{
    public DeadlockException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public override int StatusCode => StatusCodes.Status409Conflict;
    public override string Title => "Conflicto de concurrencia";
}

public sealed class DatabaseException : ApiException
{
    public DatabaseException(string message, Exception? innerException = null)
        : base(message, innerException)
    {
    }

    public override int StatusCode => StatusCodes.Status500InternalServerError;
    public override string Title => "Error de base de datos";
}