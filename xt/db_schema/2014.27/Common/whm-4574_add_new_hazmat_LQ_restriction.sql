-- Add new shipping restriction Hazmat LQ

BEGIN;

INSERT INTO ship_restriction(title, code) VALUES('Hazmat LQ', 'HZMT_LQ');

COMMIT;
