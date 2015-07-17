
BEGIN;

-- Introduce new column with reference to recode table
ALTER TABLE putaway_prep_group ADD COLUMN recode_id INTEGER REFERENCES stock_recode(id) DEFERRABLE;

-- Allo group_id to be null, so in case if putaway_prep_group stands for recode, this field is empty
ALTER TABLE putaway_prep_group ALTER COLUMN group_id DROP NOT NULL;

-- Add constraint to ensure that row has either recode_id or group_id, but not both of them
ALTER TABLE putaway_prep_group ADD CHECK (
       (recode_id IS NOT NULL AND group_id IS NULL)
    OR (recode_id IS NULL     AND group_id IS NOT NULL)
);

COMMIT;
