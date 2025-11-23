-- Script PostgreSQL para gestión de monedas y cambios monetarios
-- Paradigma declarativo aplicado a problemas de base de datos

-- =============================================
-- 1. CREACIÓN DE FUNCIONES DE VALIDACIÓN Y GESTIÓN
-- =============================================

-- Función para validar si una moneda existe
CREATE OR REPLACE FUNCTION validar_moneda_existente(
    p_sigla VARCHAR(5)
) 
RETURNS BOOLEAN AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM moneda 
        WHERE Sigla = p_sigla
    ) INTO v_existe;
    
    RETURN v_existe;
END;
$$ LANGUAGE plpgsql;

-- Función para validar si un cambio ya existe para una fecha y moneda específica
CREATE OR REPLACE FUNCTION validar_cambio_existente(
    p_id_moneda INT,
    p_fecha DATE
) 
RETURNS BOOLEAN AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM cambiomoneda 
        WHERE IdMoneda = p_id_moneda 
        AND DATE(Fecha) = p_fecha
    ) INTO v_existe;
    
    RETURN v_existe;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 2. FUNCIÓN PARA AGREGAR NUEVAS MONEDAS
-- =============================================

CREATE OR REPLACE FUNCTION agregar_moneda(
    p_moneda VARCHAR(100),
    p_sigla VARCHAR(5),
    p_simbolo VARCHAR(5),
    p_emisor VARCHAR(100)
) 
RETURNS INT AS $$
DECLARE
    v_nuevo_id INT;
BEGIN
    -- Insertar nueva moneda
    INSERT INTO moneda (Moneda, Sigla, Simbolo, Emisor, Imagen)
    VALUES (p_moneda, p_sigla, p_simbolo, p_emisor, NULL)
    RETURNING Id INTO v_nuevo_id;
    
    RETURN v_nuevo_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al agregar moneda: %', SQLERRM;
        RETURN -1;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 3. FUNCIÓN PARA ACTUALIZAR O INSERTAR CAMBIOS
-- =============================================

CREATE OR REPLACE FUNCTION actualizar_cambio_moneda(
    p_id_moneda INT,
    p_fecha DATE,
    p_cambio FLOAT
) 
RETURNS VOID AS $$
BEGIN
    -- Verificar si el cambio ya existe
    IF validar_cambio_existente(p_id_moneda, p_fecha) THEN
        -- Actualizar cambio existente
        UPDATE cambiomoneda 
        SET Cambio = p_cambio
        WHERE IdMoneda = p_id_moneda 
        AND DATE(Fecha) = p_fecha;
        
        RAISE NOTICE 'Cambio actualizado para moneda ID: %, fecha: %', p_id_moneda, p_fecha;
    ELSE
        -- Insertar nuevo cambio
        INSERT INTO cambiomoneda (IdMoneda, Fecha, Cambio)
        VALUES (p_id_moneda, p_fecha, p_cambio);
        
        RAISE NOTICE 'Nuevo cambio insertado para moneda ID: %, fecha: %', p_id_moneda, p_fecha;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 4. PROCEDIMIENTO PRINCIPAL PARA ALIMENTAR CAMBIOS
-- =============================================

CREATE OR REPLACE PROCEDURE alimentar_cambios_diarios()
AS $$
DECLARE
    -- Monedas a procesar (USD, EUR, GBP, JPY)
    v_monedas TEXT[] := ARRAY['USD', 'EUR', 'GBP', 'JPY'];
    v_moneda_nombre TEXT[] := ARRAY['Dólar Estadounidense', 'Euro', 'Libra Esterlina', 'Yen Japonés'];
    v_moneda_simbolo TEXT[] := ARRAY['$', '€', '£', '¥'];
    v_moneda_emisor TEXT[] := ARRAY['Sistema de la Reserva Federal', 'Banco Central Europeo', 'Banco de Inglaterra', 'Banco de Japón'];
    
    v_id_moneda INT;
    v_sigla TEXT;
    v_fecha_actual DATE;
    v_fecha_inicio DATE;
    v_fecha_loop DATE;
    v_cambio FLOAT;
    v_dias INTEGER;
    i INTEGER;
    
BEGIN
    -- Calcular fechas (últimos 2 meses)
    v_fecha_actual := CURRENT_DATE;
    v_fecha_inicio := v_fecha_actual - INTERVAL '2 months';
    
    RAISE NOTICE 'Iniciando proceso de alimentación de cambios desde % hasta %', 
                 v_fecha_inicio, v_fecha_actual;
    
    -- Procesar cada moneda
    FOR i IN 1..array_length(v_monedas, 1) LOOP
        v_sigla := v_monedas[i];
        
        RAISE NOTICE 'Procesando moneda: %', v_sigla;
        
        -- Validar si la moneda existe
        IF NOT validar_moneda_existente(v_sigla) THEN
            -- Agregar nueva moneda
            RAISE NOTICE 'Moneda % no existe. Agregando...', v_sigla;
            
            v_id_moneda := agregar_moneda(
                v_moneda_nombre[i],
                v_sigla,
                v_moneda_simbolo[i],
                v_moneda_emisor[i]
            );
            
            IF v_id_moneda = -1 THEN
                RAISE WARNING 'No se pudo agregar la moneda: %', v_sigla;
                CONTINUE; -- Saltar a la siguiente moneda
            END IF;
            
            RAISE NOTICE 'Moneda agregada con ID: %', v_id_moneda;
        ELSE
            -- Obtener ID de moneda existente
            SELECT Id INTO v_id_moneda 
            FROM moneda 
            WHERE Sigla = v_sigla;
            
            RAISE NOTICE 'Moneda % existe con ID: %', v_sigla, v_id_moneda;
        END IF;
        
        -- Generar cambios para los últimos 60 días
        v_dias := 0;
        v_fecha_loop := v_fecha_inicio;
        
        WHILE v_fecha_loop <= v_fecha_actual LOOP
            -- Generar cambio aleatorio (simulación de datos reales)
            -- En un caso real, aquí se conectaría a una API de cambios
            v_cambio := 0.8 + (RANDOM() * 0.4); -- Valores entre 0.8 y 1.2
            
            -- Ajustar valores típicos por moneda
            CASE v_sigla
                WHEN 'USD' THEN v_cambio := 0.9 + (RANDOM() * 0.2);  -- ~0.9-1.1
                WHEN 'EUR' THEN v_cambio := 0.85 + (RANDOM() * 0.15); -- ~0.85-1.0
                WHEN 'GBP' THEN v_cambio := 0.75 + (RANDOM() * 0.1);  -- ~0.75-0.85
                WHEN 'JPY' THEN v_cambio := 0.007 + (RANDOM() * 0.002); -- ~0.007-0.009
            END CASE;
            
            -- Actualizar o insertar cambio
            PERFORM actualizar_cambio_moneda(v_id_moneda, v_fecha_loop, v_cambio);
            
            -- Incrementar fecha
            v_fecha_loop := v_fecha_loop + INTERVAL '1 day';
            v_dias := v_dias + 1;
        END LOOP;
        
        RAISE NOTICE 'Procesados % días para moneda %', v_dias, v_sigla;
    END LOOP;
    
    RAISE NOTICE 'Proceso de alimentación completado exitosamente';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error en el proceso de alimentación: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 5. FUNCIÓN PARA CONSULTAR CAMBIOS POR MONEDA
-- =============================================

CREATE OR REPLACE FUNCTION consultar_cambios_moneda(
    p_sigla_moneda VARCHAR(5),
    p_dias INTEGER DEFAULT 30
) 
RETURNS TABLE(
    fecha DATE,
    cambio FLOAT,
    moneda_nombre VARCHAR(100),
    simbolo VARCHAR(5)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE(cm.Fecha) as fecha,
        cm.Cambio as cambio,
        m.Moneda as moneda_nombre,
        m.Simbolo as simbolo
    FROM cambiomoneda cm
    INNER JOIN moneda m ON cm.IdMoneda = m.Id
    WHERE m.Sigla = p_sigla_moneda
    AND DATE(cm.Fecha) >= CURRENT_DATE - (p_dias || ' days')::INTERVAL
    ORDER BY cm.Fecha DESC;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- 6. EJECUCIÓN DEL SCRIPT PRINCIPAL
-- =============================================

DO $$
BEGIN
    -- Ejecutar el procedimiento principal
    CALL alimentar_cambios_diarios();
    
    -- Mostrar resumen de cambios insertados/actualizados
    RAISE NOTICE 'Resumen del proceso:';
    RAISE NOTICE 'Monedas en sistema: %', (SELECT COUNT(*) FROM moneda);
    RAISE NOTICE 'Cambios registrados: %', (SELECT COUNT(*) FROM cambiomoneda);
    
    -- Ejemplo de consulta de cambios recientes
    RAISE NOTICE 'Últimos 5 cambios del USD:';
    
    FOR registro IN 
        SELECT fecha, cambio, moneda_nombre, simbolo 
        FROM consultar_cambios_moneda('USD', 5)
    LOOP
        RAISE NOTICE '  %: % %', registro.fecha, registro.simbolo, registro.cambio;
    END LOOP;
    
END $$;

-- =============================================
-- 7. SCRIPT DE VERIFICACIÓN (OPCIONAL)
-- =============================================

-- Consulta para verificar los datos insertados
SELECT 
    m.Sigla as "Moneda",
    m.Moneda as "Nombre",
    COUNT(cm.IdMoneda) as "Total Cambios",
    MIN(DATE(cm.Fecha)) as "Fecha Inicio",
    MAX(DATE(cm.Fecha)) as "Fecha Fin"
FROM moneda m
LEFT JOIN cambiomoneda cm ON m.Id = cm.IdMoneda
GROUP BY m.Id, m.Sigla, m.Moneda
ORDER BY m.Sigla;