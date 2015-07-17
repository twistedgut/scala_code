-- We're not bothering to enforce classifications product types for
-- JimmyChoo products. It makes more semantic sense to assign them to
-- N/A categories so we are adding N/A where appropriate.
BEGIN;

-- CLassification
INSERT INTO classification ( classification ) VALUES (
    'N/A'
);

-- Product Type
INSERT INTO product_type ( product_type ) VALUES (
    'N/A'
);

-- Sub type
INSERT INTO sub_type ( sub_type, product_type_id ) VALUES (
    'N/A',
    ( SELECT id FROM product_type WHERE product_type = 'N/A' )
);

COMMIT;
