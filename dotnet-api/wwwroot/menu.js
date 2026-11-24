'use strict';
const $ = id => document.getElementById(id);
const estado = $('estado');
const respuesta = $('respuesta');
const registrar = $('registrar');
const anular = $('anular');
let ocupado = false;
const factura = () => `DMENU-${Date.now()}`;
registrar.elements.numeroFactura.value = factura();

async function solicitar(metodo, ruta, datos) {
    if (ocupado) return null;
    ocupado = true;
    const botones = Array.from(document.querySelectorAll('form button'));
    botones.forEach(b => b.disabled = true);
    estado.className = 'status';
    estado.textContent = `${metodo} ${ruta} — procesando...`;
    respuesta.textContent = 'Esperando respuesta de la API...';
    try {
        const opciones = { method: metodo, headers: { Accept: 'application/json, application/problem+json' } };
        if (datos !== undefined) {
            opciones.headers['Content-Type'] = 'application/json';
            opciones.body = JSON.stringify(datos);
        }
        const res = await fetch(ruta, opciones);
        const texto = await res.text();
        let cuerpo;
        try { cuerpo = JSON.parse(texto); } catch { cuerpo = texto; }
        estado.className = `status ${res.ok ? 'ok' : 'bad'}`;
        estado.textContent = `${metodo} ${ruta} — HTTP ${res.status} ${res.statusText}`;
        respuesta.textContent = typeof cuerpo === 'string' ? cuerpo : JSON.stringify(cuerpo, null, 2);
        return { ok: res.ok, status: res.status, cuerpo };
    } catch (error) {
        estado.className = 'status bad';
        estado.textContent = 'No se pudo obtener una respuesta de la API.';
        respuesta.textContent = `${error.message}\nSi era una venta, comprueba su estado antes de reenviar la solicitud.`;
        return null;
    } finally {
        ocupado = false;
        botones.forEach(b => b.disabled = false);
    }
}
const valor = (form, campo) => form.elements[campo].value;
const numero = (form, campo) => Number(valor(form, campo));
function conectar(id, accion) {
    $(id).addEventListener('submit', async e => {
        e.preventDefault();
        if (!ocupado) await accion(e.currentTarget);
    });
}
conectar('stock', () => solicitar('GET', '/api/productos/stock-bajo'));
conectar('movimientos', form => solicitar('GET', `/api/productos/${numero(form, 'productoId')}/movimientos`));
conectar('empleado', form => solicitar('GET', `/api/empleados/${numero(form, 'empleadoId')}/ventas`));
conectar('registrar', async form => {
    const resultado = await solicitar('POST', '/api/ventas', {
        numeroFactura: valor(form, 'numeroFactura').trim(),
        clienteId: numero(form, 'clienteId'),
        empleadoId: numero(form, 'empleadoId'),
        formaPago: valor(form, 'formaPago').trim(),
        productoId: numero(form, 'productoId'),
        cantidad: numero(form, 'cantidad')
    });
    if (resultado?.status === 201 && Number.isInteger(resultado.cuerpo?.ventaId)) {
        anular.elements.ventaId.value = resultado.cuerpo.ventaId;
        form.elements.numeroFactura.value = factura();
    }
});
conectar('anular', async form => {
    const id = numero(form, 'ventaId');
    if (!window.confirm(`¿Confirmas la anulación de la venta ${id}?`)) return;
    const resultado = await solicitar('POST', `/api/ventas/${id}/anular`);
    if (resultado?.ok) form.elements.ventaId.value = '';
});
