# Taller de Integración — Comisariato

## Universidad

PUCE Manabí — Carrera de Software

## Asignatura

Prácticas en Gestión de la Información

## Descripción

Integración de dos aplicaciones independientes, desarrolladas en Java y .NET, sobre una base de datos PostgreSQL compartida. Las aplicaciones no comparten código ni se comunican entre sí; la base de datos es el artefacto común.

## Tecnologías

- Java 21 y Spring Boot 3 (`feature/java-api`).
- Apache Maven.
- .NET 8 y ASP.NET Core (`feature/dotnet-api`).
- PostgreSQL 18 y pgAdmin 4.
- Git y GitHub.

## Estructura

- `java-api/`: aplicación Java.
- `dotnet-api/`: aplicación .NET.
- `database/`: scripts compartidos de base de datos.
- `docs/`: documentación acordada por el equipo; las capturas y exportaciones locales están ignoradas.
- `postman/`: pruebas de las APIs.
- `bruno/`: colección de Bruno de la API .NET (17 peticiones).
- `dotnet-api-tests/`: pruebas automatizadas de la API .NET (xUnit).

---

## API .NET

La API utiliza ADO.NET con Npgsql, sin Entity Framework. Está adaptada a los procedimientos, la función y la vista de `database/Comisariato_demo.sql`, disponible en la rama `main`.

### Requisitos

- .NET SDK 8.
- PostgreSQL 18.
- Una base vacía llamada `Comisariato`, restaurada con `database/Comisariato_demo.sql`.
- Un usuario con permisos de lectura y escritura sobre esa base.

El script de datos debe ejecutarse **una sola vez sobre una base vacía**. No lo ejecutes sobre una base que contenga información que necesites conservar.

### Configurar la conexión

`appsettings.json` y `appsettings.example.json` contienen placeholders, no credenciales reales. `appsettings.Development.json` solo configura el logging. Antes de ejecutar, reemplaza la cadena mediante la variable de entorno `ConnectionStrings__DefaultConnection`.

Linux o macOS:

```bash
export ConnectionStrings__DefaultConnection="Host=localhost;Port=5432;Database=Comisariato;Username=TU_USUARIO;Password=TU_CLAVE"
export ASPNETCORE_URLS="http://localhost:5080"
```

Windows PowerShell:

```powershell
$env:ConnectionStrings__DefaultConnection="Host=localhost;Port=5432;Database=Comisariato;Username=TU_USUARIO;Password=TU_CLAVE"
$env:ASPNETCORE_URLS="http://localhost:5080"
```

### Ejecutar

```bash
cd dotnet-api
dotnet restore
dotnet run
```

Recursos disponibles:

- Swagger UI: `http://localhost:5080/swagger`
- OpenAPI JSON: `http://localhost:5080/swagger/v1/swagger.json`
- Health check: `http://localhost:5080/health`
- Menú web de operaciones: `http://localhost:5080/menu.html`

### Endpoints

| Método | Ruta | Operación |
|---|---|---|
| `POST` | `/api/ventas` | Registrar una venta de un producto. |
| `POST` | `/api/ventas/{ventaId}/anular` | Anular una venta y restaurar su stock. |
| `GET` | `/api/productos/stock-bajo` | Consultar productos con stock bajo. |
| `GET` | `/api/empleados/{empleadoId}/ventas` | Consultar ventas por empleado. |
| `GET` | `/api/productos/{productoId}/movimientos` | Consultar movimientos por producto. |

### Registrar una venta

El SQL compartido admite **un producto por venta**. El request no contiene precios, descuentos, subtotal, IVA ni total: esos importes los calcula el procedimiento almacenado.

```http
POST http://localhost:5080/api/ventas
Content-Type: application/json
```

```json
{
  "numeroFactura": "F-DN-001",
  "clienteId": 1,
  "empleadoId": 1,
  "formaPago": "Efectivo",
  "productoId": 1,
  "cantidad": 2
}
```

`clienteId` es opcional. `formaPago` admite `Efectivo`, `Tarjeta` o `Transferencia`. Usa un número de factura que no exista en los datos de demostración.

Respuesta `201 Created` para el ejemplo anterior, cuyo precio en los datos iniciales es `1.10`:

```json
{
  "ventaId": 3,
  "numeroFactura": "F-DN-001",
  "fechaVenta": "2026-11-24T15:00:00",
  "subtotal": 2.20,
  "iva": 0.33,
  "total": 2.53,
  "formaPago": "Efectivo",
  "estado": "Completada"
}
```

El `ventaId` y la fecha dependen del estado de la base.

Códigos principales:

- `201`: venta registrada.
- `400`: request incompleto o inválido.
- `404`: cliente, empleado o producto inexistente; también aplica a empleados o productos inactivos al registrar.
- `409`: número de factura duplicado.
- `422`: stock insuficiente o regla de integridad incumplida.
- `500`: error inesperado.

### Anular una venta

```http
POST http://localhost:5080/api/ventas/3/anular
```

No requiere body. La API bloquea la venta, obtiene internamente su empleado y ejecuta `usp_anularventa`.

- `200`: anulada y stock restaurado.
- `404`: la venta no existe.
- `409`: ya estaba anulada o su estado no permite anularla.

### Contrato con la base compartida

La implementación está alineada con estos objetos del SQL de `main`:

| Objeto | Contrato utilizado |
|---|---|
| `public.usp_registrarventa` | Procedimiento con factura, cliente, empleado, forma de pago, producto, cantidad y `INOUT p_ventaid`. |
| `public.usp_anularventa` | Procedimiento con `p_ventaid` y `p_empleadoid`. |
| `public.fn_ventasporempleado` | Devuelve `ventaid`, `numerofactura`, `fechaventa` y `total`. |
| `public.vw_productosstockbajo` | Devuelve `productoid`, `nombre`, `stock`, `stockminimo` y `categoria`. |
| `public.movimientosinventario` | Fuente de la consulta de movimientos por producto. |

Las validaciones de existencia, estado y stock se realizan dentro de la misma transacción del servicio. Los productos y las ventas se bloquean antes de invocar los procedimientos. Cada intento utiliza una conexión y una transacción nuevas; Polly realiza un único reintento después de un segundo ante `40P01` o `40001`.

### Pruebas

- Pruebas automatizadas (xUnit):

  ```bash
  dotnet test dotnet-api-tests/Comisariato.Api.Tests.csproj
  ```

  Verifican el manejo del HTTP 500 y el reintento de Polly ante deadlock.

- Pruebas de extremo a extremo con la colección de Bruno incluida en `bruno/`:

  ```bash
  bru run bruno/Comisariato-API-DotNet --env Demo
  ```

  17 peticiones y 24 pruebas; requiere una base limpia (facturas `F-DEMO-001` y
  `F-DEMO-002`).

### Errores y registros

Las respuestas de error usan `ProblemDetails`. Los fallos se registran con nivel `Error`, contexto y stack trace; las operaciones exitosas usan `Information`. La configuración local y las credenciales no deben incluirse en los commits.
