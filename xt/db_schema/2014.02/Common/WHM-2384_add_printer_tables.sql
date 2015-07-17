-- Add tables for new printer system

BEGIN;

    -- Create a new schema for the printer tables
    CREATE SCHEMA printer;
    ALTER SCHEMA printer OWNER TO www;

    -- currently one of item_count, labelling, packing, personalised_sticker,
    -- premier_shipping, qc, returns_in, returns_qc or stock_in
    CREATE TABLE printer.section (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
    );
    ALTER TABLE printer.section OWNER TO www;

    -- e.g. 'Packing Station 10'
    CREATE TABLE printer.location (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        section_id INT NOT NULL REFERENCES printer.section(id) DEFERRABLE
    );
    CREATE INDEX location_section_id_ix ON printer.location (section_id);
    ALTER TABLE printer.location OWNER TO www;

    -- currently one of carrier_label, document, large_label, mrp_card,
    -- nap_card, small_label
    CREATE TABLE printer.type (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
    );
    ALTER TABLE printer.type OWNER TO www;

    CREATE TABLE printer.printer (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        lp_name TEXT NOT NULL,
        type_id INT NOT NULL REFERENCES printer.type(id) DEFERRABLE,
        location_id INT NOT NULL REFERENCES printer.location(id) DEFERRABLE,
        created_at timestamptz NOT NULL default now()
    );
    -- Let's be strict here for now and only allow one printer type in each
    -- location - we can always remove this restriction at a later date if we
    -- decide to
    ALTER TABLE printer.printer ADD UNIQUE (type_id, location_id);
    ALTER TABLE printer.printer OWNER TO www;

COMMIT;
