BEGIN;

ALTER TABLE sessions RENAME COLUMN a_session TO session_data;

COMMIT;
