-- Copia para desarrollo: clientes, empleados y proveedores con datos sinteticos.
-- Restaurar con psql 18 en una base vacia. No ejecutar sobre una BD existente.
--
-- PostgreSQL database dump
--

\restrict hgkA6kD3RihSSfdYhiAcO1TtoC72S12VjJEdYCGKGEud4oVXO53tMtOr3xB80Cz

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

-- Started on 2026-11-24 12:15:33

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 242 (class 1255 OID 16651)
-- Name: fn_auditarcambioprecio(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_auditarcambioprecio() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO public.MovimientosInventario (
        ProductoID,
        TipoMovimiento,
        Cantidad,
        StockAnterior,
        StockNuevo,
        ReferenciaTipo,
        ReferenciaID,
        EmpleadoID
    )
    VALUES (
        NEW.ProductoID,
        'Ajuste',
        0,
        OLD.Stock,
        NEW.Stock,
        NULL,
        NULL,
        NULL
    );

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_auditarcambioprecio() OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 16650)
-- Name: fn_ventasporempleado(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_ventasporempleado(p_empleadoid integer) RETURNS TABLE(ventaid integer, numerofactura character varying, fechaventa timestamp without time zone, total numeric)
    LANGUAGE sql
    AS $$
    SELECT
        v.VentaID::INTEGER,
        v.NumeroFactura::VARCHAR(20),
        v.FechaVenta::TIMESTAMP,
        v.Total::NUMERIC(10,2)
    FROM public.Ventas v
    WHERE v.EmpleadoID = p_EmpleadoID;
$$;


ALTER FUNCTION public.fn_ventasporempleado(p_empleadoid integer) OWNER TO postgres;

--
-- TOC entry 254 (class 1255 OID 16654)
-- Name: usp_anularventa(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.usp_anularventa(IN p_ventaid integer, IN p_empleadoid integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_Estado VARCHAR(20);
    v_StockAnterior INTEGER;
    v_Detalle RECORD;
BEGIN

    -- 1. Verificar que la venta exista
    -- y bloquearla durante la anulacion
    SELECT Estado
    INTO v_Estado
    FROM public.Ventas
    WHERE VentaID = p_VentaID
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La venta no existe';
    END IF;

    -- Validar que este completada
    IF v_Estado <> 'Completada' THEN
        RAISE EXCEPTION
        'La venta no esta en estado Completada';
    END IF;

    -- Verificar que tenga productos
    IF NOT EXISTS (
        SELECT 1
        FROM public.DetalleVenta
        WHERE VentaID = p_VentaID
    ) THEN
        RAISE EXCEPTION
        'La venta no tiene detalles';
    END IF;

    -- 2. Cambiar estado a Anulada
    UPDATE public.Ventas
    SET Estado = 'Anulada'
    WHERE VentaID = p_VentaID;

    -- 3. Recorrer los productos de la venta
    FOR v_Detalle IN
        SELECT
            ProductoID,
            SUM(Cantidad)::INTEGER AS Cantidad
        FROM public.DetalleVenta
        WHERE VentaID = p_VentaID
        GROUP BY ProductoID
        ORDER BY ProductoID
    LOOP

        -- Bloquear producto y obtener stock
        SELECT Stock
        INTO v_StockAnterior
        FROM public.Productos
        WHERE ProductoID = v_Detalle.ProductoID
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
            'Producto % no encontrado',
            v_Detalle.ProductoID;
        END IF;

        -- Devolver las unidades al inventario
        UPDATE public.Productos
        SET Stock = Stock + v_Detalle.Cantidad
        WHERE ProductoID = v_Detalle.ProductoID;

        -- 4. Registrar movimiento de Entrada
        INSERT INTO public.MovimientosInventario (
            ProductoID,
            TipoMovimiento,
            Cantidad,
            StockAnterior,
            StockNuevo,
            ReferenciaTipo,
            ReferenciaID,
            EmpleadoID
        )
        VALUES (
            v_Detalle.ProductoID,
            'Entrada',
            v_Detalle.Cantidad,
            v_StockAnterior,
            v_StockAnterior + v_Detalle.Cantidad,
            'Venta',
            p_VentaID,
            p_EmpleadoID
        );

    END LOOP;

    RAISE NOTICE
    'Venta % anulada correctamente', p_VentaID;

END;
$$;


ALTER PROCEDURE public.usp_anularventa(IN p_ventaid integer, IN p_empleadoid integer) OWNER TO postgres;

--
-- TOC entry 240 (class 1255 OID 16645)
-- Name: usp_registrarventa(character varying, integer, integer, character varying, integer, integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.usp_registrarventa(IN p_numerofactura character varying, IN p_clienteid integer, IN p_empleadoid integer, IN p_formapago character varying, IN p_productoid integer, IN p_cantidad integer, INOUT p_ventaid integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_StockActual INTEGER;
    v_PrecioUnitario NUMERIC(10,2);
    v_Subtotal NUMERIC(10,2);
    v_IVA NUMERIC(10,2);
    v_Total NUMERIC(10,2);
BEGIN

    -- 1. Validar producto y bloquear su fila
    SELECT Stock, PrecioVenta
    INTO v_StockActual, v_PrecioUnitario
    FROM public.Productos
    WHERE ProductoID = p_ProductoID
      AND Activo = TRUE
    FOR UPDATE;

    IF v_StockActual IS NULL THEN
        RAISE EXCEPTION
        'Producto inexistente o inactivo';
    END IF;

    IF v_StockActual < p_Cantidad THEN
        RAISE EXCEPTION
        'Stock insuficiente para la venta';
    END IF;

    -- 2. Calcular importes
    v_Subtotal := ROUND(
        p_Cantidad * v_PrecioUnitario, 2
    );

    v_IVA := ROUND(v_Subtotal * 0.15, 2);
    v_Total := v_Subtotal + v_IVA;

    -- 3. Insertar cabecera de venta
    INSERT INTO public.Ventas (
        NumeroFactura,
        ClienteID,
        EmpleadoID,
        Subtotal,
        IVA,
        Total,
        FormaPago,
        Estado
    )
    VALUES (
        p_NumeroFactura,
        p_ClienteID,
        p_EmpleadoID,
        v_Subtotal,
        v_IVA,
        v_Total,
        p_FormaPago,
        'Completada'
    )
    RETURNING VentaID INTO p_VentaID;

    -- 4. Registrar detalle
    INSERT INTO public.DetalleVenta (
        VentaID,
        ProductoID,
        Cantidad,
        PrecioUnitario
    )
    VALUES (
        p_VentaID,
        p_ProductoID,
        p_Cantidad,
        v_PrecioUnitario
    );

    -- 5. Actualizar inventario
    UPDATE public.Productos
    SET Stock = Stock - p_Cantidad
    WHERE ProductoID = p_ProductoID;

    -- 6. Registrar movimiento
    INSERT INTO public.MovimientosInventario (
        ProductoID,
        TipoMovimiento,
        Cantidad,
        StockAnterior,
        StockNuevo,
        ReferenciaTipo,
        ReferenciaID,
        EmpleadoID
    )
    VALUES (
        p_ProductoID,
        'Salida',
        p_Cantidad,
        v_StockActual,
        v_StockActual - p_Cantidad,
        'Venta',
        p_VentaID,
        p_EmpleadoID
    );

END;
$$;


ALTER PROCEDURE public.usp_registrarventa(IN p_numerofactura character varying, IN p_clienteid integer, IN p_empleadoid integer, IN p_formapago character varying, IN p_productoid integer, IN p_cantidad integer, INOUT p_ventaid integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 220 (class 1259 OID 16390)
-- Name: categorias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categorias (
    categoriaid integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying(255),
    activa boolean DEFAULT true NOT NULL
);


ALTER TABLE public.categorias OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16389)
-- Name: categorias_categoriaid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.categorias ALTER COLUMN categoriaid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categorias_categoriaid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 224 (class 1259 OID 16417)
-- Name: clientes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clientes (
    clienteid integer NOT NULL,
    cedula character varying(10) NOT NULL,
    nombres character varying(100) NOT NULL,
    apellidos character varying(100) NOT NULL,
    telefono character varying(20),
    email character varying(100),
    fecharegistro timestamp(0) without time zone DEFAULT (clock_timestamp())::timestamp(0) without time zone NOT NULL
);


ALTER TABLE public.clientes OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16416)
-- Name: clientes_clienteid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.clientes ALTER COLUMN clienteid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.clientes_clienteid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 234 (class 1259 OID 16548)
-- Name: compras; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.compras (
    compraid integer NOT NULL,
    numeroorden character varying(20) NOT NULL,
    proveedorid integer NOT NULL,
    empleadoid integer NOT NULL,
    fechacompra timestamp(0) without time zone DEFAULT (clock_timestamp())::timestamp(0) without time zone NOT NULL,
    total numeric(10,2) NOT NULL,
    estado character varying(20) DEFAULT 'Recibida'::character varying NOT NULL,
    CONSTRAINT ck_compras_estado CHECK (((estado)::text = ANY ((ARRAY['Pendiente'::character varying, 'Recibida'::character varying, 'Anulada'::character varying])::text[]))),
    CONSTRAINT ck_compras_total CHECK ((total >= (0)::numeric))
);


ALTER TABLE public.compras OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 16547)
-- Name: compras_compraid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.compras ALTER COLUMN compraid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.compras_compraid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 236 (class 1259 OID 16577)
-- Name: detallecompra; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detallecompra (
    detallecompraid integer NOT NULL,
    compraid integer NOT NULL,
    productoid integer NOT NULL,
    cantidad integer NOT NULL,
    costounitario numeric(10,2) NOT NULL,
    subtotallinea numeric(12,2) GENERATED ALWAYS AS (((cantidad)::numeric * costounitario)) STORED,
    CONSTRAINT ck_dc_cantidad CHECK ((cantidad > 0)),
    CONSTRAINT ck_dc_costo CHECK ((costounitario >= (0)::numeric))
);


ALTER TABLE public.detallecompra OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 16576)
-- Name: detallecompra_detallecompraid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.detallecompra ALTER COLUMN detallecompraid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.detallecompra_detallecompraid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 232 (class 1259 OID 16518)
-- Name: detalleventa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detalleventa (
    detalleventaid integer NOT NULL,
    ventaid integer NOT NULL,
    productoid integer NOT NULL,
    cantidad integer NOT NULL,
    preciounitario numeric(10,2) NOT NULL,
    descuento numeric(10,2) DEFAULT 0 NOT NULL,
    subtotallinea numeric(12,2) GENERATED ALWAYS AS ((((cantidad)::numeric * preciounitario) - descuento)) STORED,
    CONSTRAINT ck_dv_cantidad CHECK ((cantidad > 0)),
    CONSTRAINT ck_dv_descuento CHECK ((descuento >= (0)::numeric)),
    CONSTRAINT ck_dv_descuentomaximo CHECK ((descuento <= ((cantidad)::numeric * preciounitario))),
    CONSTRAINT ck_dv_precio CHECK ((preciounitario >= (0)::numeric))
);


ALTER TABLE public.detalleventa OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16517)
-- Name: detalleventa_detalleventaid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.detalleventa ALTER COLUMN detalleventaid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.detalleventa_detalleventaid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 226 (class 1259 OID 16431)
-- Name: empleados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empleados (
    empleadoid integer NOT NULL,
    cedula character varying(10) NOT NULL,
    nombres character varying(100) NOT NULL,
    apellidos character varying(100) NOT NULL,
    cargo character varying(50) NOT NULL,
    fechaingreso date NOT NULL,
    salario numeric(10,2) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_empleados_salario CHECK ((salario > (0)::numeric))
);


ALTER TABLE public.empleados OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16430)
-- Name: empleados_empleadoid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.empleados ALTER COLUMN empleadoid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.empleados_empleadoid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 238 (class 1259 OID 16603)
-- Name: movimientosinventario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.movimientosinventario (
    movimientoid bigint NOT NULL,
    productoid integer NOT NULL,
    tipomovimiento character varying(20) NOT NULL,
    cantidad integer NOT NULL,
    stockanterior integer NOT NULL,
    stocknuevo integer NOT NULL,
    referenciatipo character varying(20),
    referenciaid integer,
    fechamovimiento timestamp(0) without time zone DEFAULT (clock_timestamp())::timestamp(0) without time zone NOT NULL,
    empleadoid integer,
    CONSTRAINT ck_movinv_cantidad CHECK (((cantidad > 0) OR (((tipomovimiento)::text = 'Ajuste'::text) AND (cantidad = 0)))),
    CONSTRAINT ck_movinv_deltaentrada CHECK ((((tipomovimiento)::text <> 'Entrada'::text) OR (stocknuevo = (stockanterior + cantidad)))),
    CONSTRAINT ck_movinv_deltasalida CHECK ((((tipomovimiento)::text <> 'Salida'::text) OR (stocknuevo = (stockanterior - cantidad)))),
    CONSTRAINT ck_movinv_referenciacompleta CHECK ((((referenciatipo IS NULL) AND (referenciaid IS NULL)) OR ((referenciatipo IS NOT NULL) AND (referenciaid IS NOT NULL)))),
    CONSTRAINT ck_movinv_reftipo CHECK ((((referenciatipo)::text = ANY ((ARRAY['Venta'::character varying, 'Compra'::character varying, 'Ajuste'::character varying])::text[])) OR (referenciatipo IS NULL))),
    CONSTRAINT ck_movinv_stockanterior CHECK ((stockanterior >= 0)),
    CONSTRAINT ck_movinv_stocknuevo CHECK ((stocknuevo >= 0)),
    CONSTRAINT ck_movinv_tipo CHECK (((tipomovimiento)::text = ANY ((ARRAY['Entrada'::character varying, 'Salida'::character varying, 'Ajuste'::character varying])::text[])))
);


ALTER TABLE public.movimientosinventario OWNER TO postgres;

--
-- TOC entry 237 (class 1259 OID 16602)
-- Name: movimientosinventario_movimientoid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.movimientosinventario ALTER COLUMN movimientoid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.movimientosinventario_movimientoid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 228 (class 1259 OID 16449)
-- Name: productos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productos (
    productoid integer NOT NULL,
    codigobarras character varying(50) NOT NULL,
    nombre character varying(150) NOT NULL,
    categoriaid integer NOT NULL,
    proveedorid integer,
    preciocompra numeric(10,2) NOT NULL,
    precioventa numeric(10,2) NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    stockminimo integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_productos_margen CHECK ((precioventa >= preciocompra)),
    CONSTRAINT ck_productos_preciocompra CHECK ((preciocompra >= (0)::numeric)),
    CONSTRAINT ck_productos_precioventa CHECK ((precioventa >= (0)::numeric)),
    CONSTRAINT ck_productos_stock CHECK ((stock >= 0)),
    CONSTRAINT ck_productos_stockmin CHECK ((stockminimo >= 0))
);


ALTER TABLE public.productos OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16448)
-- Name: productos_productoid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.productos ALTER COLUMN productoid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.productos_productoid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 222 (class 1259 OID 16402)
-- Name: proveedores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proveedores (
    proveedorid integer NOT NULL,
    ruc character varying(13) NOT NULL,
    razonsocial character varying(150) NOT NULL,
    telefono character varying(20),
    email character varying(100),
    direccion character varying(255),
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE public.proveedores OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16401)
-- Name: proveedores_proveedorid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.proveedores ALTER COLUMN proveedorid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.proveedores_proveedorid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 230 (class 1259 OID 16484)
-- Name: ventas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ventas (
    ventaid integer NOT NULL,
    numerofactura character varying(20) NOT NULL,
    clienteid integer,
    empleadoid integer NOT NULL,
    fechaventa timestamp(0) without time zone DEFAULT (clock_timestamp())::timestamp(0) without time zone NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    iva numeric(10,2) NOT NULL,
    total numeric(10,2) NOT NULL,
    formapago character varying(30) NOT NULL,
    estado character varying(20) DEFAULT 'Completada'::character varying NOT NULL,
    CONSTRAINT ck_ventas_estado CHECK (((estado)::text = ANY ((ARRAY['Pendiente'::character varying, 'Completada'::character varying, 'Anulada'::character varying])::text[]))),
    CONSTRAINT ck_ventas_formapago CHECK (((formapago)::text = ANY ((ARRAY['Efectivo'::character varying, 'Tarjeta'::character varying, 'Transferencia'::character varying])::text[]))),
    CONSTRAINT ck_ventas_iva CHECK ((iva >= (0)::numeric)),
    CONSTRAINT ck_ventas_subtotal CHECK ((subtotal >= (0)::numeric)),
    CONSTRAINT ck_ventas_total CHECK ((total >= (0)::numeric))
);


ALTER TABLE public.ventas OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16483)
-- Name: ventas_ventaid_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

ALTER TABLE public.ventas ALTER COLUMN ventaid ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.ventas_ventaid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 239 (class 1259 OID 16646)
-- Name: vw_productosstockbajo; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_productosstockbajo AS
 SELECT p.productoid,
    p.nombre,
    p.stock,
    p.stockminimo,
    c.nombre AS categoria
   FROM (public.productos p
     JOIN public.categorias c ON ((c.categoriaid = p.categoriaid)))
  WHERE (p.stock <= p.stockminimo);


ALTER VIEW public.vw_productosstockbajo OWNER TO postgres;

--
-- TOC entry 5162 (class 0 OID 16390)
-- Dependencies: 220
-- Data for Name: categorias; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categorias (categoriaid, nombre, descripcion, activa) FROM stdin;
1	Lácteos	Leche, quesos, yogures	t
2	Bebidas	Gaseosas, jugos, agua	t
3	Aseo	Detergentes, jabones	t
4	Snacks	Papas, galletas, dulces	t
5	Granos	Arroz, azúcar, sal	t
\.


--
-- TOC entry 5166 (class 0 OID 16417)
-- Dependencies: 224
-- Data for Name: clientes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clientes (clienteid, cedula, nombres, apellidos, telefono, email, fecharegistro) FROM stdin;
1	0000000001	Cliente 1	Prueba	\N	cliente1@example.invalid	2026-10-27 11:30:39
2	0000000002	Cliente 2	Prueba	\N	cliente2@example.invalid	2026-10-27 11:30:39
3	0000000003	Cliente 3	Prueba	\N	cliente3@example.invalid	2026-10-27 11:30:39
\.


--
-- TOC entry 5176 (class 0 OID 16548)
-- Dependencies: 234
-- Data for Name: compras; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.compras (compraid, numeroorden, proveedorid, empleadoid, fechacompra, total, estado) FROM stdin;
\.


--
-- TOC entry 5178 (class 0 OID 16577)
-- Dependencies: 236
-- Data for Name: detallecompra; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detallecompra (detallecompraid, compraid, productoid, cantidad, costounitario) FROM stdin;
\.


--
-- TOC entry 5174 (class 0 OID 16518)
-- Dependencies: 232
-- Data for Name: detalleventa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detalleventa (detalleventaid, ventaid, productoid, cantidad, preciounitario, descuento) FROM stdin;
1	1	1	2	1.10	0.00
2	1	3	1	1.90	0.00
3	2	1	2	1.10	0.00
\.


--
-- TOC entry 5168 (class 0 OID 16431)
-- Dependencies: 226
-- Data for Name: empleados; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empleados (empleadoid, cedula, nombres, apellidos, cargo, fechaingreso, salario, activo) FROM stdin;
1	0000000101	Empleado 1	Prueba	Cajero	2025-01-01	500.00	t
2	0000000102	Empleado 2	Prueba	Bodeguero	2025-01-01	500.00	t
3	0000000103	Empleado 3	Prueba	Supervisor	2025-01-01	500.00	t
\.


--
-- TOC entry 5180 (class 0 OID 16603)
-- Dependencies: 238
-- Data for Name: movimientosinventario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.movimientosinventario (movimientoid, productoid, tipomovimiento, cantidad, stockanterior, stocknuevo, referenciatipo, referenciaid, fechamovimiento, empleadoid) FROM stdin;
1	1	Salida	5	98	93	Ajuste	1	2026-10-27 12:31:32	1
2	1	Salida	2	93	91	Venta	2	2026-11-17 11:27:00	1
6	2	Ajuste	0	40	40	\N	\N	2026-11-17 11:53:49	\N
7	1	Entrada	2	91	93	Venta	2	2026-11-17 11:59:26	1
\.


--
-- TOC entry 5170 (class 0 OID 16449)
-- Dependencies: 228
-- Data for Name: productos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.productos (productoid, codigobarras, nombre, categoriaid, proveedorid, preciocompra, precioventa, stock, stockminimo, activo) FROM stdin;
4	7503000000015	Detergente 1kg	3	1	2.10	3.00	30	10	t
5	7504000000012	Papas Fritas 150g	4	3	0.60	1.00	80	20	t
6	7505000000019	Arroz 5lb	5	1	2.40	3.20	50	15	t
7	7505000000026	Azúcar 2kg	5	1	1.50	2.10	45	10	t
3	7502000000010	Gaseosa Cola 2L	2	3	1.20	1.90	59	15	t
2	7501000000028	Queso Fresco 500g	1	2	2.50	3.90	40	10	t
1	7501000000011	Leche Entera 1L	1	2	0.75	1.10	93	20	t
\.


--
-- TOC entry 5164 (class 0 OID 16402)
-- Dependencies: 222
-- Data for Name: proveedores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proveedores (proveedorid, ruc, razonsocial, telefono, email, direccion, activo) FROM stdin;
1	0000000000001	Proveedor de prueba 1	\N	proveedor1@example.invalid	\N	t
2	0000000000002	Proveedor de prueba 2	\N	proveedor2@example.invalid	\N	t
3	0000000000003	Proveedor de prueba 3	\N	proveedor3@example.invalid	\N	t
\.


--
-- TOC entry 5172 (class 0 OID 16484)
-- Dependencies: 230
-- Data for Name: ventas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ventas (ventaid, numerofactura, clienteid, empleadoid, fechaventa, subtotal, iva, total, formapago, estado) FROM stdin;
1	F-0001	1	1	2026-10-27 11:50:13	3.00	0.36	3.36	Efectivo	Completada
2	F-001	1	1	2026-11-17 11:27:00	2.20	0.33	2.53	Efectivo	Anulada
\.


--
-- TOC entry 5186 (class 0 OID 0)
-- Dependencies: 219
-- Name: categorias_categoriaid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categorias_categoriaid_seq', 7, true);


--
-- TOC entry 5187 (class 0 OID 0)
-- Dependencies: 223
-- Name: clientes_clienteid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clientes_clienteid_seq', 3, true);


--
-- TOC entry 5188 (class 0 OID 0)
-- Dependencies: 233
-- Name: compras_compraid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.compras_compraid_seq', 1, false);


--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 235
-- Name: detallecompra_detallecompraid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detallecompra_detallecompraid_seq', 1, false);


--
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 231
-- Name: detalleventa_detalleventaid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detalleventa_detalleventaid_seq', 3, true);


--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 225
-- Name: empleados_empleadoid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empleados_empleadoid_seq', 3, true);


--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 237
-- Name: movimientosinventario_movimientoid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.movimientosinventario_movimientoid_seq', 7, true);


--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 227
-- Name: productos_productoid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.productos_productoid_seq', 7, true);


--
-- TOC entry 5194 (class 0 OID 0)
-- Dependencies: 221
-- Name: proveedores_proveedorid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proveedores_proveedorid_seq', 3, true);


--
-- TOC entry 5195 (class 0 OID 0)
-- Dependencies: 229
-- Name: ventas_ventaid_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ventas_ventaid_seq', 2, true);


--
-- TOC entry 4952 (class 2606 OID 16398)
-- Name: categorias pk_categorias; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT pk_categorias PRIMARY KEY (categoriaid);


--
-- TOC entry 4960 (class 2606 OID 16427)
-- Name: clientes pk_clientes; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT pk_clientes PRIMARY KEY (clienteid);


--
-- TOC entry 4988 (class 2606 OID 16563)
-- Name: compras pk_compras; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT pk_compras PRIMARY KEY (compraid);


--
-- TOC entry 4993 (class 2606 OID 16589)
-- Name: detallecompra pk_detallecompra; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detallecompra
    ADD CONSTRAINT pk_detallecompra PRIMARY KEY (detallecompraid);


--
-- TOC entry 4982 (class 2606 OID 16534)
-- Name: detalleventa pk_detalleventa; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalleventa
    ADD CONSTRAINT pk_detalleventa PRIMARY KEY (detalleventaid);


--
-- TOC entry 4964 (class 2606 OID 16445)
-- Name: empleados pk_empleados; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empleados
    ADD CONSTRAINT pk_empleados PRIMARY KEY (empleadoid);


--
-- TOC entry 4999 (class 2606 OID 16623)
-- Name: movimientosinventario pk_movimientosinventario; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientosinventario
    ADD CONSTRAINT pk_movimientosinventario PRIMARY KEY (movimientoid);


--
-- TOC entry 4970 (class 2606 OID 16470)
-- Name: productos pk_productos; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT pk_productos PRIMARY KEY (productoid);


--
-- TOC entry 4956 (class 2606 OID 16413)
-- Name: proveedores pk_proveedores; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT pk_proveedores PRIMARY KEY (proveedorid);


--
-- TOC entry 4977 (class 2606 OID 16504)
-- Name: ventas pk_ventas; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT pk_ventas PRIMARY KEY (ventaid);


--
-- TOC entry 4954 (class 2606 OID 16400)
-- Name: categorias uq_categorias_nombre; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT uq_categorias_nombre UNIQUE (nombre);


--
-- TOC entry 4962 (class 2606 OID 16429)
-- Name: clientes uq_clientes_cedula; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clientes
    ADD CONSTRAINT uq_clientes_cedula UNIQUE (cedula);


--
-- TOC entry 4990 (class 2606 OID 16565)
-- Name: compras uq_compras_numeroorden; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT uq_compras_numeroorden UNIQUE (numeroorden);


--
-- TOC entry 4995 (class 2606 OID 16591)
-- Name: detallecompra uq_dc_compra_producto; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detallecompra
    ADD CONSTRAINT uq_dc_compra_producto UNIQUE (compraid, productoid);


--
-- TOC entry 4984 (class 2606 OID 16536)
-- Name: detalleventa uq_dv_venta_producto; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalleventa
    ADD CONSTRAINT uq_dv_venta_producto UNIQUE (ventaid, productoid);


--
-- TOC entry 4966 (class 2606 OID 16447)
-- Name: empleados uq_empleados_cedula; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empleados
    ADD CONSTRAINT uq_empleados_cedula UNIQUE (cedula);


--
-- TOC entry 4972 (class 2606 OID 16472)
-- Name: productos uq_productos_codigobarras; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT uq_productos_codigobarras UNIQUE (codigobarras);


--
-- TOC entry 4958 (class 2606 OID 16415)
-- Name: proveedores uq_proveedores_ruc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT uq_proveedores_ruc UNIQUE (ruc);


--
-- TOC entry 4979 (class 2606 OID 16506)
-- Name: ventas uq_ventas_numerofactura; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT uq_ventas_numerofactura UNIQUE (numerofactura);


--
-- TOC entry 4985 (class 1259 OID 16641)
-- Name: ix_compras_empleadoid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_compras_empleadoid ON public.compras USING btree (empleadoid);


--
-- TOC entry 4986 (class 1259 OID 16640)
-- Name: ix_compras_proveedorid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_compras_proveedorid ON public.compras USING btree (proveedorid);


--
-- TOC entry 4991 (class 1259 OID 16642)
-- Name: ix_detallecompra_productoid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_detallecompra_productoid ON public.detallecompra USING btree (productoid);


--
-- TOC entry 4980 (class 1259 OID 16639)
-- Name: ix_detalleventa_productoid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_detalleventa_productoid ON public.detalleventa USING btree (productoid);


--
-- TOC entry 4996 (class 1259 OID 16644)
-- Name: ix_movinv_empleadoid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_movinv_empleadoid ON public.movimientosinventario USING btree (empleadoid);


--
-- TOC entry 4997 (class 1259 OID 16643)
-- Name: ix_movinv_productoid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_movinv_productoid ON public.movimientosinventario USING btree (productoid);


--
-- TOC entry 4967 (class 1259 OID 16634)
-- Name: ix_productos_categoriaid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_productos_categoriaid ON public.productos USING btree (categoriaid);


--
-- TOC entry 4968 (class 1259 OID 16635)
-- Name: ix_productos_proveedorid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_productos_proveedorid ON public.productos USING btree (proveedorid);


--
-- TOC entry 4973 (class 1259 OID 16636)
-- Name: ix_ventas_clienteid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_ventas_clienteid ON public.ventas USING btree (clienteid);


--
-- TOC entry 4974 (class 1259 OID 16637)
-- Name: ix_ventas_empleadoid; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_ventas_empleadoid ON public.ventas USING btree (empleadoid);


--
-- TOC entry 4975 (class 1259 OID 16638)
-- Name: ix_ventas_fechaventa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_ventas_fechaventa ON public.ventas USING btree (fechaventa);


--
-- TOC entry 5012 (class 2620 OID 16652)
-- Name: productos trg_auditarcambioprecio; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_auditarcambioprecio AFTER UPDATE OF precioventa ON public.productos FOR EACH ROW WHEN ((old.precioventa IS DISTINCT FROM new.precioventa)) EXECUTE FUNCTION public.fn_auditarcambioprecio();


--
-- TOC entry 5006 (class 2606 OID 16571)
-- Name: compras fk_compras_empleados; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT fk_compras_empleados FOREIGN KEY (empleadoid) REFERENCES public.empleados(empleadoid);


--
-- TOC entry 5007 (class 2606 OID 16566)
-- Name: compras fk_compras_proveedores; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.compras
    ADD CONSTRAINT fk_compras_proveedores FOREIGN KEY (proveedorid) REFERENCES public.proveedores(proveedorid);


--
-- TOC entry 5008 (class 2606 OID 16592)
-- Name: detallecompra fk_detallecompra_compras; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detallecompra
    ADD CONSTRAINT fk_detallecompra_compras FOREIGN KEY (compraid) REFERENCES public.compras(compraid);


--
-- TOC entry 5009 (class 2606 OID 16597)
-- Name: detallecompra fk_detallecompra_productos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detallecompra
    ADD CONSTRAINT fk_detallecompra_productos FOREIGN KEY (productoid) REFERENCES public.productos(productoid);


--
-- TOC entry 5004 (class 2606 OID 16542)
-- Name: detalleventa fk_detalleventa_productos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalleventa
    ADD CONSTRAINT fk_detalleventa_productos FOREIGN KEY (productoid) REFERENCES public.productos(productoid);


--
-- TOC entry 5005 (class 2606 OID 16537)
-- Name: detalleventa fk_detalleventa_ventas; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detalleventa
    ADD CONSTRAINT fk_detalleventa_ventas FOREIGN KEY (ventaid) REFERENCES public.ventas(ventaid);


--
-- TOC entry 5010 (class 2606 OID 16629)
-- Name: movimientosinventario fk_movinv_empleados; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientosinventario
    ADD CONSTRAINT fk_movinv_empleados FOREIGN KEY (empleadoid) REFERENCES public.empleados(empleadoid);


--
-- TOC entry 5011 (class 2606 OID 16624)
-- Name: movimientosinventario fk_movinv_productos; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.movimientosinventario
    ADD CONSTRAINT fk_movinv_productos FOREIGN KEY (productoid) REFERENCES public.productos(productoid);


--
-- TOC entry 5000 (class 2606 OID 16473)
-- Name: productos fk_productos_categorias; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_productos_categorias FOREIGN KEY (categoriaid) REFERENCES public.categorias(categoriaid);


--
-- TOC entry 5001 (class 2606 OID 16478)
-- Name: productos fk_productos_proveedores; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.productos
    ADD CONSTRAINT fk_productos_proveedores FOREIGN KEY (proveedorid) REFERENCES public.proveedores(proveedorid);


--
-- TOC entry 5002 (class 2606 OID 16507)
-- Name: ventas fk_ventas_clientes; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_clientes FOREIGN KEY (clienteid) REFERENCES public.clientes(clienteid);


--
-- TOC entry 5003 (class 2606 OID 16512)
-- Name: ventas fk_ventas_empleados; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ventas
    ADD CONSTRAINT fk_ventas_empleados FOREIGN KEY (empleadoid) REFERENCES public.empleados(empleadoid);


-- Completed on 2026-11-24 12:15:33

--
-- PostgreSQL database dump complete
--

\unrestrict hgkA6kD3RihSSfdYhiAcO1TtoC72S12VjJEdYCGKGEud4oVXO53tMtOr3xB80Cz

