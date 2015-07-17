-- DCA-45 Make user_id a foreign key to operator(id)

BEGIN;

ALTER TABLE putaway_prep_container ALTER COLUMN user_id TYPE INTEGER USING CAST(user_id AS INTEGER);
ALTER TABLE putaway_prep_container ADD FOREIGN KEY (user_id) REFERENCES operator(id) DEFERRABLE;

COMMIT;
