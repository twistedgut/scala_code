-- We don't need a unique constraint on a PK

BEGIN;
    ALTER TABLE operator_preferences DROP CONSTRAINT uniq_operator_id;
COMMIT;
