# Comisariato — API Java

Módulo independiente del taller de Práctica en Gestión de la Información (PUCE Manabí). Consume la base Comisariato compartida con .NET; no requiere que la otra API esté en ejecución.

## Requisitos

- Java 21, Maven y PostgreSQL 18.
- Base Comisariato con sus procedimientos, funciones y vistas.
- Acceso a PostgreSQL mediante un usuario con permisos apropiados.

Si ya existe la base del taller, utilizarla sin restaurar nuevamente. Para una instalación limpia de demostración, crear una base vacía Comisariato y restaurar `database/Comisariato_demo.sql` con `psql` 18 desde la raíz del repositorio. El script contiene datos sintéticos y objetos con propietario postgres.

```sh
createdb -U postgres Comisariato
psql -X -v ON_ERROR_STOP=1 -U postgres -d Comisariato -f database/Comisariato_demo.sql
```

## Configuración y ejecución

Desde `java-api` en PowerShell:

```powershell
if (-not (Test-Path .\src\main\resources\application.yml)) {
    Copy-Item .\src\main\resources\application.yml.example .\src\main\resources\application.yml
}
$env:DB_URL = 'jdbc:postgresql://localhost:5432/Comisariato'
$env:DB_USER = 'postgres'
$env:DB_PASSWORD = [System.Net.NetworkCredential]::new('', (Read-Host 'Contraseña PostgreSQL' -AsSecureString)).Password
mvn clean test
mvn spring-boot:run
```

En Linux (Bash), desde `java-api`:

```bash
[ -f src/main/resources/application.yml ] || cp src/main/resources/application.yml.example src/main/resources/application.yml
export DB_URL='jdbc:postgresql://localhost:5432/Comisariato'
export DB_USER='postgres'
read -rsp 'Contraseña PostgreSQL: ' DB_PASSWORD; echo
export DB_PASSWORD
mvn clean test
mvn spring-boot:run
```

No publicar contraseñas ni `application.yml` local. El archivo de ejemplo utiliza variables de entorno y `DatabaseConfig` configura HikariCP a partir de las propiedades `spring.datasource`.

## Acceso

- Menú de operaciones: http://localhost:8080/menu.html
- Swagger UI: http://localhost:8080/swagger-ui.html
- Health check: http://localhost:8080/actuator/health
- OpenAPI: http://localhost:8080/v3/api-docs

## Operaciones

| Método | Ruta | Resultado esperado |
|---|---|---|
| GET | `/api/productos/stock-bajo` | 200 |
| GET | `/api/productos/{productoId}/movimientos` | 200 |
| GET | `/api/empleados/{empleadoId}/ventas` | 200, 404 |
| POST | `/api/ventas` | 201, 400, 409, 422 |
| POST | `/api/ventas/{ventaId}/anular` | 200, 400, 404, 409 |

Los errores inesperados devuelven HTTP 500. Los errores se representan mediante ProblemDetail. El total lo calcula el procedimiento almacenado, no el cliente.

Ejemplo de registro (usar una factura única y los IDs existentes en la BD):

```json
{"numeroFactura":"DEMO-JAVA-01","clienteId":1,"empleadoId":1,"formaPago":"Efectivo","productoId":1,"cantidad":2}
```

Para anular, utilizar el `ventaId` devuelto y enviar `{"empleadoId":1}`. Verificar en PostgreSQL que se repongan las unidades. Las pruebas de escritura deben hacerse con datos de demostración y conservar el historial de movimientos.

## Arquitectura y transacciones

`controller → service → repository`, con `config` para el origen de datos. Se utiliza Spring JDBC sin JPA/Hibernate. Las escrituras llaman a los procedimientos existentes dentro de transacciones de servicio. `DeadlockRetry` reintenta una sola vez después de 1000 ms ante SQLSTATE `40P01` de PostgreSQL; el reintento se realiza fuera de la transacción fallida.

## Pruebas

- `mvn clean test`: pruebas JUnit, Mockito y MockMvc, incluida la respuesta HTTP 500.
- Importar `docs/Comisariato_Java.postman_collection.json` (relativo a la raíz del repositorio). Ejecutar el registro antes de la anulación y confirmar el inventario.
- Revisar los registros de Spring Boot y las consultas en pgAdmin para las pruebas de deadlock y consistencia.

La guía original menciona SQL Server y el error 1205. Este proyecto usa PostgreSQL y su equivalente 40P01; la aceptación académica de esa adaptación debe confirmarse con la docente.
