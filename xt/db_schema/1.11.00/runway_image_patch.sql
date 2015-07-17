
BEGIN;

update photography.image_label set short_description = 'RW' where short_description = 'RU';

COMMIT;

