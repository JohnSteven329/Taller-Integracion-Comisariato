using Microsoft.Extensions.Diagnostics.HealthChecks;
using Npgsql;

namespace Comisariato.Api.Infrastructure;

/// <summary>Comprueba que PostgreSQL responda con SELECT 1.</summary>
public sealed class DatabaseHealthCheck : IHealthCheck
{
    private readonly NpgsqlDataSource _dataSource;

    public DatabaseHealthCheck(NpgsqlDataSource dataSource)
    {
        _dataSource = dataSource;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = await _dataSource.OpenConnectionAsync(cancellationToken);
            await using var command = new NpgsqlCommand("SELECT 1", connection);
            var result = await command.ExecuteScalarAsync(cancellationToken);
            return result is int value && value == 1
                ? HealthCheckResult.Healthy("PostgreSQL disponible.")
                : HealthCheckResult.Degraded("PostgreSQL respondió un valor inesperado.");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("PostgreSQL no disponible.", ex);
        }
    }
}