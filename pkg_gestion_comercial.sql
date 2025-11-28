/*
  PROYECTO: Sistema de Gestión Comercial Enterprise
  AUTOR: Sandro Cusihuaman
  ARQUITECTURA: PL/SQL Packages + Row-level Processing
  DESCRIPCIÓN: Implementación de lógica de negocio modularizada mediante
               Paquetes, con control transaccional ACID y procesamiento Batch.
*/

-- =========================================================
-- 1. CREACIÓN DE TABLAS (Infraestructura de Datos)
-- =========================================================

-- Tabla de Clientes
CREATE TABLE clientes (
    id_cliente NUMBER PRIMARY KEY,
    nombre VARCHAR2(100),
    linea_credito NUMBER
);

-- Tabla de Productos
CREATE TABLE productos (
    id_producto NUMBER PRIMARY KEY,
    nombre VARCHAR2(50),
    stock NUMBER,
    precio NUMBER
);

-- Tabla de Auditoría
CREATE TABLE auditoria_transacciones (
    id_log NUMBER GENERATED ALWAYS AS IDENTITY,
    mensaje VARCHAR2(400),
    fecha DATE DEFAULT SYSDATE
);

-- Datos semilla (Mock Data para pruebas)
INSERT INTO clientes VALUES (1, 'Empresa Tech SAC', 5000);
INSERT INTO clientes VALUES (2, 'Consultora Global', 1000);
INSERT INTO productos VALUES (100, 'Servidor Rack', 5, 2000);
INSERT INTO productos VALUES (101, 'Licencia Software', 50, 300);
COMMIT;

-- =========================================================
-- 2. ESPECIFICACIÓN DEL PAQUETE (La "Fachada")
-- =========================================================
/* Define la interfaz pública del sistema. 
   Oculta la complejidad de la implementación (Encapsulamiento).
*/
CREATE OR REPLACE PACKAGE pkg_gestion_comercial IS
    
    -- Servicio transaccional: Procesa ventas validando reglas de negocio complejas
    PROCEDURE procesar_venta_corporativa(
        p_cliente_id IN NUMBER,
        p_producto_id IN NUMBER,
        p_cantidad IN NUMBER
    );

    -- Servicio Batch: Analiza el inventario completo fila por fila
    PROCEDURE reporte_stock_critico;

END pkg_gestion_comercial;
/

-- =========================================================
-- 3. CUERPO DEL PAQUETE (La Lógica de Negocio)
-- =========================================================
/* Implementación detallada de la lógica.
   Incluye manejo de transacciones, cursores y excepciones.
*/
CREATE OR REPLACE PACKAGE BODY pkg_gestion_comercial IS

    -- IMPLEMENTACIÓN: procesar_venta_corporativa
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
        -- 1. Obtención de datos actuales (Snapshot)
        SELECT stock, precio INTO v_stock, v_precio 
        FROM productos WHERE id_producto = p_producto_id;
        
        SELECT linea_credito INTO v_credito 
        FROM clientes WHERE id_cliente = p_cliente_id;

        -- Calculamos el total de la transacción
        v_total := v_precio * p_cantidad;

        -- 2. VALIDACIÓN DE REGLAS DE NEGOCIO (Business Rules)
        IF v_stock < p_cantidad THEN
            -- Regla 1: No vender sin stock físico
            RAISE_APPLICATION_ERROR(-20001, 'STOCK INSUFICIENTE: No hay unidades disponibles.');
            
        ELSIF v_credito < v_total THEN
            -- Regla 2: No vender si el cliente excede su línea de crédito
            RAISE_APPLICATION_ERROR(-20002, 'CRÉDITO INSUFICIENTE: El cliente no tiene saldo para esta compra.');
            
        ELSE
            -- 3. EJECUCIÓN TRANSACCIONAL (ACID)
            -- Si pasa las validaciones, ejecutamos todos los cambios
            
            -- Actualizar Inventario
            UPDATE productos SET stock = stock - p_cantidad 
            WHERE id_producto = p_producto_id;
            
            -- Cargar cobro al cliente
            UPDATE clientes SET linea_credito = linea_credito - v_total 
            WHERE id_cliente = p_cliente_id;
            
            -- Generar Auditoría
            INSERT INTO auditoria_transacciones (mensaje) 
            VALUES ('VENTA EXITOSA: Cliente '||p_cliente_id||' adquirió '||p_cantidad||' unds. de prod '||p_producto_id||' por $'||v_total);
            
            -- Confirmar transacción
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('>> Transacción procesada correctamente. Total: $' || v_total);
        END IF;

    EXCEPTION
        -- Manejo de errores robusto
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('ERROR: El Cliente o Producto especificado no existe en la base de datos.');
            ROLLBACK; -- Revertir cualquier cambio parcial
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('ERROR CRÍTICO DEL SISTEMA: ' || SQLERRM);
            ROLLBACK;
    END procesar_venta_corporativa;


    -- IMPLEMENTACIÓN: reporte_stock_critico
    PROCEDURE reporte_stock_critico IS
        -- Definición de CURSOR EXPLÍCITO para recorrido secuencial
        CURSOR c_productos IS
            SELECT nombre, stock FROM productos;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- INICIO DE AUDITORÍA DE STOCK (BATCH) ---');
        
        -- Bucle de procesamiento fila por fila
        FOR r_prod IN c_productos LOOP
            -- Lógica de semáforo para el stock
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