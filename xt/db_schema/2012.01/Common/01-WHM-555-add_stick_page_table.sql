-- Add table to store sticky page details

BEGIN;

    -- Sticky page table
    CREATE TABLE operator.sticky_page (
        operator_id integer PRIMARY KEY REFERENCES public.operator(id) DEFERRABLE NOT NULL,
        signature text NOT NULL,
        html text,
        sticky_class text NOT NULL,
        sticky_id integer NOT NULL
    );

    ALTER TABLE operator.sticky_page OWNER TO www;

COMMIT;
