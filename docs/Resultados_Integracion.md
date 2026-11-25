# Resultados de integración — Comisariato

Fecha: 24 de noviembre de 2026. Versión probada: `8efbb8a` de `main`. Fuente: `Entrega_Final_Comisariato.zip` (reporte `Resultados_Integracion.md`, 39 capturas y video de demostración). Este documento resume la ejecución registrada, no una nueva ejecución de pruebas.

## Instancia común

Java (8080) y .NET (5080) consumieron la misma base PostgreSQL 18 `Comisariato`. Se comprobaron los menús, Swagger, health checks, consultas y escrituras cruzadas. El producto 1 llegó al umbral de 20 unidades y apareció en ambas consultas de stock bajo. El empleado 2 devolvió HTTP 200 con `[]` en las dos aplicaciones.

## Ventas y movimientos comprobados

| Factura | Venta ID | Registro | Anulación | Unidades | Salida / entrada |
|---|---:|---|---|---:|---|
| JAVA-1845426837 | 12 | Java | .NET | 73 | 21 / 22 |
| NET-1845426837 | 13 | .NET | Java | 2 | 23 / 24 |
| CJ-1845426837 | 16 | Java (concurrente) | .NET | 1 | 25 / 27 |
| CN-1845426837 | 17 | .NET (concurrente) | Java | 2 | 26 / 28 |

Las cuatro ventas quedaron anuladas. Las consultas cruzadas comprobaron que ambas aplicaciones observaban los mismos datos sin llamarse directamente entre sí.

## Concurrencia y consistencia

Las solicitudes simultáneas por una y dos unidades devolvieron HTTP 201. El reporte registra 28,56 ms de solapamiento medido en el cliente (no equivale a medir la duración de los bloqueos internos). El stock de 93 unidades pasó a 90 y volvió a 93 tras las anulaciones. En el conjunto de la demostración se registraron cuatro movimientos de salida y cuatro de entrada por 78 unidades en cada sentido, sin duplicados en los movimientos examinados.

## Validación, errores y recuperación

| Código | Comprobación registrada en ambas APIs |
|---|---|
| 200 | Consultas, anulación y empleado existente sin ventas |
| 201 | Registro de venta |
| 400 | Datos inválidos |
| 404 | Empleado inexistente |
| 409 | Factura duplicada y anulación repetida |
| 422 | Stock insuficiente |
| 500 | Excepción controlada mediante pruebas automatizadas |

Los casos 400 y 422 no generaron ventas para las cuatro facturas inválidas examinadas. Maven/JUnit reportó 8/8 y xUnit 5/5. En pruebas individuales previas, Postman reportó 10/10 y Bruno 24/24 comprobaciones (17 solicitudes).

Los deadlocks reales se documentaron en ejecuciones individuales previas: Java (venta 9, HTTP 201) y .NET (venta 5 anulada), con SQLSTATE `40P01` y reintento tras 1000 ms. El video incorpora esas evidencias históricas; no reproduce un nuevo deadlock. La anulación de una venta inexistente (404) corresponde a pruebas individuales previas, no a la demostración conjunta. El reporte original también indica que no quedaron sesiones en espera de bloqueo ni inactivas en transacción; no hay una captura independiente de esa comprobación en el ZIP final.

## Evidencias de referencia (entrega externa)

Los siguientes nombres corresponden a archivos dentro de la carpeta `evidencias/` del ZIP de entrega, no a archivos versionados en Git.

| Evidencia | Archivo |
|---|---|
| Venta Java y consulta .NET | `06-Java-venta-registrada.png`, `12-NET-consulta-venta-Java.png` |
| Anulación cruzada .NET | `15-NET-anulacion-venta-Java.png` |
| Venta .NET y consulta Java | `18-NET-venta-registrada.png`, `20-Java-consulta-venta-NET.png` |
| Anulación cruzada Java | `21-Java-anulacion-venta-NET.png` |
| Concurrencia | `30-concurrencia-solicitudes.png`, `31-concurrencia-respuestas.png` |
| Registros históricos de deadlock | `34-04-Java-deadlock-real.png`, `35-03-DotNet-deadlock-real.png` |
| Pruebas automatizadas | `36-01-Java-Maven-500-y-reintentos.png`, `37-02-DotNet-xUnit-500-y-Polly.png` |
| Verificación PostgreSQL | `38-pgAdmin-ventas-y-movimientos.png`, `39-pgAdmin-balance-final.png` |

Video: `Video_Demostracion_Comisariato.mp4`, 3 min 42 s, 1920 × 1080, H.264, sin pista de audio. Informe técnico y video se presentan por separado.

## Alcance académico

La guía utiliza SQL Server (deadlock 1205). La implementación emplea PostgreSQL 18 y su equivalente `40P01`. Queda confirmar la aceptación académica de esta adaptación. Las evidencias documentan los casos probados; no constituyen una garantía de corrección para todos los escenarios posibles.
