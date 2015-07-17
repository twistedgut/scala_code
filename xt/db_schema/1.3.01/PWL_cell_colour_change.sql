-- they need more green!!!

BEGIN;

UPDATE photography.image_status
SET display_colour='#3D9140'
WHERE status='RETOUCH';

UPDATE photography.image_status
SET display_colour='#3D9140'
WHERE status='AMEND_RETOUCH';

COMMIT;
