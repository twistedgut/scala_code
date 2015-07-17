-- Patch to turn on the GOH PRL
-- This must not go anywhere near live until the time is right!!
BEGIN TRANSACTION;

INSERT INTO location (location)
VALUES ('GOH PRL');

UPDATE prl
SET    is_active = TRUE,
       location_id = (SELECT id FROM location WHERE location = 'GOH PRL')
WHERE  name = 'GOH';

COMMIT;
