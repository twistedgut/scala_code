-- DCA-45 More tables to record putaway progress

BEGIN;

-- Add columns
ALTER TABLE putaway_prep ADD COLUMN created TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE putaway_prep ADD COLUMN modified TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- remove columns
ALTER TABLE putaway_prep DROP CONSTRAINT putaway_prep_variant_id_fkey;
ALTER TABLE putaway_prep DROP COLUMN variant_id;
ALTER TABLE putaway_prep DROP COLUMN pgid;

ALTER TABLE putaway_prep DROP COLUMN quantity;

-- new table
CREATE SEQUENCE putaway_prep_item_id_seq
    INCREMENT BY 1 NO MAXVALUE NO MINVALUE START WITH 1 CACHE 1;

CREATE TABLE putaway_prep_item (
    id INTEGER PRIMARY KEY DEFAULT NEXTVAL('putaway_prep_item_id_seq'),
    putaway_prep_id INTEGER REFERENCES putaway_prep(id) DEFERRABLE,
    pgid VARCHAR(255) NOT NULL,
    variant_id INTEGER NOT NULL REFERENCES variant(id) DEFERRABLE,
    quantity INTEGER NOT NULL
);

COMMIT;
