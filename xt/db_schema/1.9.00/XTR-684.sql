-- This relates to XTR-684: http://animal/browse/XTR-684
--
-- this patch adds a new image type of "Runway"

BEGIN;

    UPDATE photography.image_label
    SET idx = (idx * 10);

    ALTER TABLE photography.image_label ADD UNIQUE (short_description);

    INSERT INTO photography.image_label
    (description, short_description, idx)
    VALUES
    (
        'Runway',
        'RU',
        (
            SELECT (idx + 5)
            FROM photography.image_label
            WHERE short_description = 'OS'
        )
    )
    ;

COMMIT;
