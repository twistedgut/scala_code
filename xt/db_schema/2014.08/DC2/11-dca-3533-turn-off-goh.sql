BEGIN;

UPDATE prl
SET    is_active = FALSE
WHERE  name = 'GOH';

COMMIT;
