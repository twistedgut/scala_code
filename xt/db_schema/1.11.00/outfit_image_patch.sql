
BEGIN;

update photography.image_label set short_description = 'OU' where short_description = 'OS';

COMMIT;

