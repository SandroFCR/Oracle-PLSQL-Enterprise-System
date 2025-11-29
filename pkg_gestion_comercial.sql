/*
  PROYECTO: Sistema de Gestión Comercial Enterprise
  AUTOR: Sandro Cusihuaman
  ARQUITECTURA: PL/SQL Packages + Row-level Processing

*/

-- =========================================================
-- 1. CREACIÓN DE TABLAS 
-- =========================================================

CREATE TABLE clientes (
    id_cliente NUMBER PRIMARY KEY,
    nombre VARCHAR2(100),
    linea_credito NUMBER
);

CREATE TABLE productos (
    id_producto NUMBER PRIMARY KEY,
    nombre VARCHAR2(50),
    stock NUMBER,
    precio NUMBER
);


CREATE TABLE auditoria_transacciones (
    id_log NUMBER GENERATED ALWAYS AS IDENTITY,
    mensaje VARCHAR2(400),
    fecha DATE DEFAULT SYSDATE
);

INSERT INTO clientes VALUES (1, 'Empresa Tech SAC', 5000);
INSERT INTO clientes VALUES (2, 'Consultora Global', 1000);
INSERT INTO productos VALUES (100, 'Servidor Rack', 5, 2000);
INSERT INTO productos VALUES (101, 'Licencia Software', 50, 300);
COMMIT;

-- =========================================================
-- 2. ESPECIFICACIÓN DEL PAQUETE 
-- =========================================================

CREATE OR REPLACE PACKAGE pkg_gestion_comercial IS

    PROCEDURE procesar_venta_corporativa(
        p_cliente_id IN NUMBER,
        p_producto_id IN NUMBER,
        p_cantidad IN NUMBER
    );
    PROCEDURE reporte_stock_critico;

END pkg_gestion_comercial;
/

-- =========================================================
-- 3. CUERPO DEL PAQUETE 
-- =========================================================

CREATE OR REPLACE PACKAGE BODY pkg_gestion_comercial IS


    PROCEDURE procesar_venta_corporativa(
        p_cliente_id IN NUMBER,
        p_producto_id IN NUMBER,
        p_cantidad IN NUMBER
    ) IS
        v_stock NUMBER;
        v_precio NUMBER;
        v_credito NUMBER;
        v_total NUMBER;
    BEGIN

        SELECT stock, precio INTO v_stock, v_precio 
        FROM productos WHERE id_producto = p_producto_id;
        
        SELECT linea_credito INTO v_credito 
        FROM clientes WHERE id_cliente = p_cliente_id;

        v_total := v_precio * p_cantidad;

        IF v_stock < p_cantidad THEN
            RAISE_APPLICATION_ERROR(-20001, 'STOCK INSUFICIENTE: No hay unidades disponibles.');
            
        ELSIF v_credito < v_total THEN

            RAISE_APPLICATION_ERROR(-20002, 'CRÉDITO INSUFICIENTE: El cliente no tiene saldo para esta compra.');
            
        ELSE

            UPDATE productos SET stock = stock - p_cantidad 
            WHERE id_producto = p_producto_id;
            

            UPDATE clientes SET linea_credito = linea_credito - v_total 
            WHERE id_cliente = p_cliente_id;

            INSERT INTO auditoria_transacciones (mensaje) 
            VALUES ('VENTA EXITOSA: Cliente '||p_cliente_id||' adquirió '||p_cantidad||' unds. de prod '||p_producto_id||' por $'||v_total);
            

            COMMIT;
            DBMS_OUTPUT.PUT_LINE('>> Transacción procesada correctamente. Total: $' || v_total);
        END IF;

    EXCEPTION

        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: El Cliente o Producto especificado no existe en la base de datos.');
            ROLLBACK; 
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR CRÍTICO DEL SISTEMA: ' || SQLERRM);
            ROLLBACK;
    END procesar_venta_corporativa;


    PROCEDURE reporte_stock_critico IS

        CURSOR c_productos IS
            SELECT nombre, stock FROM productos;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- INICIO DE AUDITORÍA DE STOCK (BATCH) ---');
        

        FOR r_prod IN c_productos LOOP

            IF r_prod.stock < 10 THEN
                DBMS_OUTPUT.PUT_LINE('[ALERTA] Stock Crítico detectado: ' || r_prod.nombre || ' (Quedan: ' || r_prod.stock || ')');
            ELSE
                 DBMS_OUTPUT.PUT_LINE('[OK] Stock Saludable: ' || r_prod.nombre);
            END IF;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('--- FIN DE PROCESO ---');
    END reporte_stock_critico;

END pkg_gestion_comercial;

/

