-- Add a menu entry for the sample adjustment screen and a sample log table

BEGIN;
    -- Add menu entry
    INSERT INTO authorisation_sub_section ( sub_section, authorisation_section_id, ord )
    VALUES (
        'Sample Adjustment',
        -- add to Stock Control menu
        (
            SELECT id
            FROM authorisation_section
            WHERE section = 'Stock Control'
        ),
        -- add after last item on Admin menu
        (
            SELECT MAX(ord)+1
            FROM authorisation_sub_section
            WHERE authorisation_section_id = (
                SELECT id
                FROM authorisation_section
                WHERE section = 'Stock Control'
            )
        )
    );
    -- Add log_sample_adjustment table
    CREATE TABLE log_sample_adjustment (
        id SERIAL PRIMARY KEY,
        sku TEXT NOT NULL,
        location_name TEXT NOT NULL,
        operator_name TEXT NOT NULL,
        channel_id INTEGER NOT NULL REFERENCES public.channel(id),
        notes TEXT NOT NULL,
        delta INTEGER NOT NULL,
        balance INTEGER NOT NULL,
        timestamp TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX log_sample_adjustment_sku_idx ON log_sample_adjustment ( sku );
    ALTER TABLE log_sample_adjustment OWNER TO www;
COMMIT;
