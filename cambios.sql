CREATE TABLE IF NOT EXISTS moneda (
    cod_moneda VARCHAR(3) PRIMARY KEY,
    nombre_moneda VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS cambio (
    id SERIAL PRIMARY KEY,
    cod_moneda VARCHAR(3) REFERENCES moneda(cod_moneda),
    fecha DATE NOT NULL,
    valor NUMERIC(18,6) NOT NULL,
    UNIQUE (cod_moneda, fecha)
);

INSERT INTO moneda (cod_moneda, nombre_moneda) VALUES
    ('USD', 'Dólar Estadounidense'),
    ('EUR', 'Euro'),
    ('COP', 'Peso Colombiano'),
    ('MXN', 'Peso Mexicano')
ON CONFLICT (cod_moneda) DO NOTHING;

DO $$
DECLARE
    m RECORD;
    dia DATE;
    nuevo_valor NUMERIC(18,6);
BEGIN

    FOR m IN SELECT cod_moneda FROM moneda LOOP

        FOR dia IN
            SELECT generate_series(
                CURRENT_DATE - INTERVAL '2 months',
                CURRENT_DATE,
                '1 day'
            )::date
        LOOP

            nuevo_valor := ROUND((random() * 100 + 1)::numeric, 6);

            BEGIN
                INSERT INTO cambio(cod_moneda, fecha, valor)
                VALUES (m.cod_moneda, dia, nuevo_valor);

            EXCEPTION WHEN unique_violation THEN
                UPDATE cambio
                SET valor = nuevo_valor
                WHERE cod_moneda = m.cod_moneda
                AND fecha = dia;
            END;

        END LOOP;
    END LOOP;

END$$;
