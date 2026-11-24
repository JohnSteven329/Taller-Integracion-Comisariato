using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Comisariato.Api.DTOs;
using Comisariato.Api.Services;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace Comisariato.Api.Tests;

/// <summary>
/// Prueba controlada del HTTP 500: se reemplaza el servicio real por uno que
/// lanza una excepción inesperada y se comprueba que la API responde con
/// ProblemDetails en lugar de propagar la excepción.
/// </summary>
public class Http500Tests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public Http500Tests(WebApplicationFactory<Program> factory) => _factory = factory;

    [Fact]
    public async Task ErrorInesperadoDevuelve500EnProblemDetails()
    {
        using var cliente = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IVentaService>();
                services.AddScoped<IVentaService, VentaServiceQueFalla>();
            });
        }).CreateClient();

        var request = new VentaRequest("TEST-500", 1, 1, "Efectivo", 1, 1);

        var respuesta = await cliente.PostAsJsonAsync("/api/ventas", request);

        Assert.Equal(HttpStatusCode.InternalServerError, respuesta.StatusCode);
        Assert.Equal("application/problem+json",
            respuesta.Content.Headers.ContentType?.MediaType);

        var problema = await respuesta.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(500, problema.GetProperty("status").GetInt32());
        Assert.Equal("Error de base de datos", problema.GetProperty("title").GetString());
        Assert.Equal("Ocurrió un error inesperado al procesar la solicitud.",
            problema.GetProperty("detail").GetString());
    }

    private sealed class VentaServiceQueFalla : IVentaService
    {
        public Task<VentaResponse> RegistrarAsync(VentaRequest request, CancellationToken cancellationToken = default)
            => throw new InvalidOperationException("Error interno simulado");

        public Task<VentaResponse> AnularAsync(int ventaId, CancellationToken cancellationToken = default)
            => throw new InvalidOperationException("Error interno simulado");
    }
}
