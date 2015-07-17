-- for DCS-3723
BEGIN;
	DROP TABLE session;
	ALTER TABLE sessions DROP COLUMN created;
	ALTER TABLE sessions ADD COLUMN expires integer;
COMMIT;
