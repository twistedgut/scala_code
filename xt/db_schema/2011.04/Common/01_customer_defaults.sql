BEGIN;
    ALTER TABLE customer
        ALTER COLUMN created SET DEFAULT now(),
        ALTER COLUMN modified SET DEFAULT now()
    ;
COMMIT;
