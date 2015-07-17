-- Add a field recording the date the product was added to the
-- product.list_item

BEGIN;

    ALTER TABLE product.list_item
        ADD COLUMN created
            TIMESTAMP WITH TIME ZONE
            DEFAULT CURRENT_TIMESTAMP;

    ALTER TABLE product.list_item
        ADD COLUMN created_by
            INTEGER
            REFERENCES public.operator;

    UPDATE product.list_item SET created_by = 1;

    ALTER TABLE product.list_item
        ALTER COLUMN created_by
            SET NOT NULL;
COMMIT;
