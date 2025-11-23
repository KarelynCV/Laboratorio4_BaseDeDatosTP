CREATE TABLE IF NOT EXISTS moneda (
    Id SERIAL PRIMARY KEY,
    Moneda VARCHAR(100) NOT NULL,
    Sigla VARCHAR(5) UNIQUE NOT NULL,
    Simbolo VARCHAR(5),
    Emisor VARCHAR(100),
    Imagen BYTEA
);

CREATE TABLE IF NOT EXISTS cambiomoneda (
    Id SERIAL PRIMARY KEY,
    IdMoneda INT NOT NULL REFERENCES moneda(Id) ON DELETE CASCADE,
    Fecha DATE NOT NULL,
    Cambio NUMERIC(12,6) NOT NULL,
    UNIQUE (IdMoneda, Fecha)
);

CREATE INDEX IF NOT EXISTS idx_cambiomoneda_moneda ON cambiomoneda(IdMoneda);
CREATE INDEX IF NOT EXISTS idx_cambiomoneda_fecha ON cambiomoneda(Fecha);

CREATE OR REPLACE FUNCTION validar_moneda_existente(p_sigla VARCHAR(5))
RETURNS BOOLEAN AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM moneda WHERE Sigla = p_sigla)
    INTO v_existe;
    RETURN v_existe;
END;
$$ LANGUAGE plpgsql;

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
        WHERE IdMoneda = p_id_moneda AND Fecha = p_fecha
    ) INTO v_existe;
    RETURN v_existe;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION agregar_moneda(
    p_moneda VARCHAR(100),
    p_sigla VARCHAR(5),
    p_simbolo VARCHAR(5),
    p_emisor VARCHAR(100)
)
RETURNS INT AS $$
DECLARE
    v_id INT;
BEGIN
    INSERT INTO moneda (Moneda, Sigla, Simbolo, Emisor)
    VALUES (p_moneda, p_sigla, p_simbolo, p_emisor)
    RETURNING Id INTO v_id;
    RETURN v_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al agregar moneda (%): %', p_sigla, SQLERRM;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION actualizar_cambio_moneda(
    p_id_moneda INT,
    p_fecha DATE,
    p_cambio NUMERIC
)
RETURNS VOID AS $$
BEGIN
    IF validar_cambio_existente(p_id_moneda, p_fecha) THEN
        UPDATE cambiomoneda
        SET Cambio = p_cambio
        WHERE IdMoneda = p_id_moneda AND Fecha = p_fecha;
        RAISE NOTICE 'Cambio actualizado para %, fecha %', p_id_moneda, p_fecha;
    ELSE
        INSERT INTO cambiomoneda (IdMoneda, Fecha, Cambio)
        VALUES (p_id_moneda, p_fecha, p_cambio);
        RAISE NOTICE 'Nuevo cambio insertado para %, fecha %', p_id_moneda, p_fecha;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE alimentar_cambios_diarios()
AS $$
DECLARE
    v_siglas   TEXT[] := ARRAY['USD','EUR','GBP','JPY'];
    v_nombres  TEXT[] := ARRAY['Dólar Estadounidense','Euro','Libra Esterlina','Yen Japonés'];
    v_simbolos TEXT[] := ARRAY['$','€','£','¥'];
    v_emisores TEXT[] := ARRAY['Sistema de la Reserva Federal','Banco Central Europeo','Banco de Inglaterra','Banco de Japón'];
    v_id_moneda INT;
    v_fecha_actual DATE := CURRENT_DATE;
    v_fecha_inicio DATE := CURRENT_DATE - INTERVAL '2 months';
    v_fecha DATE;
    v_cambio NUMERIC;
BEGIN
    FOR i IN 1..array_length(v_siglas, 1) LOOP
        IF NOT validar_moneda_existente(v_siglas[i]) THEN
            v_id_moneda := agregar_moneda(
                v_nombres[i],
                v_siglas[i],
                v_simbolos[i],
                v_emisores[i]
            );
        ELSE
            SELECT Id INTO v_id_moneda FROM moneda WHERE Sigla = v_siglas[i];
        END IF;
        v_fecha := v_fecha_inicio;
        WHILE v_fecha <= v_fecha_actual LOOP
            CASE v_siglas[i]
                WHEN 'USD' THEN v_cambio := 0.9 + random() * 0.2;
                WHEN 'EUR' THEN v_cambio := 0.85 + random() * 0.15;
                WHEN 'GBP' THEN v_cambio := 0.75 + random() * 0.1;
                WHEN 'JPY' THEN v_cambio := 0.007 + random() * 0.002;
            END CASE;
            PERFORM actualizar_cambio_moneda(v_id_moneda, v_fecha, v_cambio);
            v_fecha := v_fecha + 1;
        END LOOP;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS consultar_cambios_moneda(VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION consultar_cambios_moneda(
    p_sigla_moneda VARCHAR(5),
    p_dias INTEGER DEFAULT 30
)
RETURNS TABLE(
    fecha DATE,
    cambio NUMERIC,
    moneda_nombre VARCHAR(100),
    simbolo VARCHAR(5)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.Fecha,
        cm.Cambio,
        m.Moneda,
        m.Simbolo
    FROM cambiomoneda cm
    INNER JOIN moneda m ON cm.IdMoneda = m.Id
    WHERE m.Sigla = p_sigla_moneda
      AND cm.Fecha >= CURRENT_DATE - p_dias
    ORDER BY cm.Fecha DESC;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE r RECORD;
BEGIN
    CALL alimentar_cambios_diarios();
    FOR r IN SELECT * FROM consultar_cambios_moneda('USD',5) LOOP
        RAISE NOTICE '% - % %', r.fecha, r.simbolo, r.cambio;
    END LOOP;
END;
$$;

SELECT 
    m.Sigla AS "Moneda",
    m.Moneda AS "Nombre",
    COUNT(cm.IdMoneda) AS "Total Cambios",
    MIN(cm.Fecha) AS "Fecha Inicio",
    MAX(cm.Fecha) AS "Fecha Fin"
FROM moneda m
LEFT JOIN cambiomoneda cm ON m.Id = cm.IdMoneda
GROUP BY m.Id, m.Sigla, m.Moneda
ORDER BY m.Sigla;