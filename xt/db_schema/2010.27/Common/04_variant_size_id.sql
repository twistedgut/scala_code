BEGIN;
    ALTER TABLE public.variant
        ALTER COLUMN size_id SET NOT NULL,
        ALTER COLUMN type_id SET NOT NULL
    ;
COMMIT;
