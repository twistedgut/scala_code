BEGIN;

    ALTER TABLE product_attribute
        ADD COLUMN related_facts text;

COMMIT;
