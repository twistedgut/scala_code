-- Add a PK to this table

BEGIN;
    ALTER TABLE operator_preferences ADD PRIMARY KEY (operator_id);
COMMIT;
