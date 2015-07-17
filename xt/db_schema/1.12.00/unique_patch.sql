-- Patch to make sub_type.sub_type, product_type.product_type,
-- classification.classification column unique, as it should be

BEGIN;

    ALTER TABLE sub_type ADD UNIQUE ( sub_type );
    ALTER TABLE product_type ADD UNIQUE ( product_type );
    ALTER TABLE classification ADD UNIQUE ( classification );

COMMIT;
