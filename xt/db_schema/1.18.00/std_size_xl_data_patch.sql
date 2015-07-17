-- Add size mapping
BEGIN;

        INSERT INTO std_size_mapping (
        size_scheme_id,
        size_id,
        classification_id,
        product_type_id,
        std_size_id
    ) VALUES
    (
        (SELECT id FROM size_scheme WHERE name = 'RTW XS - XL'),
        (SELECT id FROM size WHERE size = 'x large'),
        (SELECT id FROM classification WHERE classification = 'Clothing'),
        NULL,
        (SELECT id FROM std_size WHERE name = 'XL')
    );

COMMIT;
