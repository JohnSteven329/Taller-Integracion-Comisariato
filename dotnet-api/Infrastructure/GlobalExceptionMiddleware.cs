using Microsoft.AspNetCore.Mvc;
using Npgsql;

namespace Comisariato.Api.Infrastructure;

/// <summary>
/// Middleware global de excepciones. Devuelve ProblemDetails (RFC 7807)
/// y registra ERROR con contexto y stacktrace.
/// </summary>
public sealed class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _logger;

    public GlobalExceptionMiddleware(RequestDelegate next, ILogger<GlobalExceptionMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            _logger.LogWarning("Solicitud cancelada por el cliente: {Method} {Path}",
                context.Request.Method, context.Request.Path);
            if (!context.Response.HasStarted)
            {
                context.Response.StatusCode = 499;
            }
        }
        catch (Exception ex)
        {
            if (context.Response.HasStarted)
            {
                _logger.LogError(ex, "Error después de iniciar la respuesta: {Method} {Path}",
                    context.Request.Method, context.Request.Path);
                throw;
            }

            var apiException = ToApiException(ex);
            var status = apiException.StatusCode;
            var detail = status >= 500
                ? "Ocurrió un error inesperado al procesar la solicitud."
                : apiException.Message;

            _logger.LogError(ex,
                "Error HTTP {Status} en {Method} {Path}: {Message}",
                status, context.Request.Method, context.Request.Path, ex.Message);

            context.Response.Clear();
            context.Response.StatusCode = status;
            context.Response.ContentType = "application/problem+json";

            var problem = new ProblemDetails
            {
                Status = status,
                Title = apiException.Title,
                Detail = detail,
                Instance = context.Request.Path,
                Type = $"https://comisariato.local/errors/{status}"
            };
            problem.Extensions["traceId"] = context.TraceIdentifier;

            await context.Response.WriteAsJsonAsync(problem);
        }
    }

    private static ApiException ToApiException(Exception ex)
    {
        return ex switch
        {
            ApiException api => api,
            PostgresException pg => (ApiException)SqlErrorMapper.Map(pg, "middleware"),
            BadHttpRequestException bad => new BadRequestException(bad.Message, bad),
            _ => new DatabaseException("Error inesperado.", ex)
        };
    }
}