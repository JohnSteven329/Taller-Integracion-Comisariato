using Polly;
using Polly.Retry;

namespace Comisariato.Api.Infrastructure;

/// <summary>
/// Política Polly: un único reintento después de 1 segundo
/// cuando el repositorio detecta un deadlock.
/// </summary>
public static class PollyPolicies
{
    public static AsyncRetryPolicy CreateDeadlockPolicy(ILogger logger)
    {
        return Policy
            .Handle<DeadlockException>()
            .WaitAndRetryAsync(
                retryCount: 1,
                sleepDurationProvider: _ => TimeSpan.FromSeconds(1),
                onRetry: (exception, delay, attempt, _) =>
                {
                    logger.LogWarning(exception,
                        "Deadlock detectado. Reintento {Attempt} en {Delay} ms.",
                        attempt, delay.TotalMilliseconds);
                });
    }
}