using Comisariato.Api.Infrastructure;
using Microsoft.Extensions.Logging;
using Xunit;

namespace Comisariato.Api.Tests;

/// <summary>
/// Comprueba la política Polly: ante un deadlock se reintenta una única vez y
/// después de un segundo; cualquier otro error se propaga sin reintentar.
/// </summary>
public class DeadlockRetryTests
{
    private sealed class LoggerEspia : ILogger
    {
        public List<string> Mensajes { get; } = new();

        public IDisposable BeginScope<TState>(TState state) where TState : notnull => new SinAlcance();

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
            => Mensajes.Add(formatter(state, exception));

        private sealed class SinAlcance : IDisposable
        {
            public void Dispose()
            {
            }
        }
    }

    [Fact]
    public async Task OperacionExitosaNoSeReintenta()
    {
        var policy = PollyPolicies.CreateDeadlockPolicy(new LoggerEspia());
        var intentos = 0;

        var resultado = await policy.ExecuteAsync(async () =>
        {
            intentos++;
            await Task.CompletedTask;
            return "OK";
        });

        Assert.Equal("OK", resultado);
        Assert.Equal(1, intentos);
    }

    [Fact]
    public async Task DeadlockSeReintentaUnaVezDespuesDeUnSegundo()
    {
        var logger = new LoggerEspia();
        var policy = PollyPolicies.CreateDeadlockPolicy(logger);
        var intentos = 0;
        var reloj = System.Diagnostics.Stopwatch.StartNew();

        var resultado = await policy.ExecuteAsync(async () =>
        {
            intentos++;
            await Task.CompletedTask;
            if (intentos == 1)
            {
                throw new DeadlockException("deadlock simulado");
            }

            return "OK";
        });

        reloj.Stop();

        Assert.Equal("OK", resultado);
        Assert.Equal(2, intentos);
        Assert.True(reloj.ElapsedMilliseconds >= 1000,
            $"El reintento esperó {reloj.ElapsedMilliseconds} ms.");
        Assert.Contains(logger.Mensajes,
            m => m.Contains("Deadlock detectado") && m.Contains("1000"));
    }

    [Fact]
    public async Task SegundoDeadlockSePropagaSinTercerIntento()
    {
        var policy = PollyPolicies.CreateDeadlockPolicy(new LoggerEspia());
        var intentos = 0;

        await Assert.ThrowsAsync<DeadlockException>(async () =>
            await policy.ExecuteAsync(async () =>
            {
                intentos++;
                await Task.CompletedTask;
                throw new DeadlockException("deadlock simulado");
            }));

        Assert.Equal(2, intentos);
    }

    [Fact]
    public async Task ErroresQueNoSonDeadlockNoSeReintentan()
    {
        var policy = PollyPolicies.CreateDeadlockPolicy(new LoggerEspia());
        var intentos = 0;

        await Assert.ThrowsAsync<ConflictException>(async () =>
            await policy.ExecuteAsync(async () =>
            {
                intentos++;
                await Task.CompletedTask;
                throw new ConflictException("factura duplicada");
            }));

        Assert.Equal(1, intentos);
    }
}
