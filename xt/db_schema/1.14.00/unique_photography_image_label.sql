BEGIN;

    ALTER TABLE photography.image_label
        ADD UNIQUE(short_description);

    ALTER TABLE photography.image_label
        ADD UNIQUE(description);

COMMIT;

