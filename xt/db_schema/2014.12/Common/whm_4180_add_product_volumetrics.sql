-- Add volumetrics to the product table

BEGIN;
    ALTER TABLE shipping_attribute
        ADD COLUMN length NUMERIC(10,3),
        ADD COLUMN width NUMERIC(10,3),
        ADD COLUMN height NUMERIC(10,3),
        -- Make sure if one measurement is inserted they all have to be
        ADD CONSTRAINT length_with_width CHECK (
            CASE
                WHEN length IS NOT NULL THEN width IS NOT NULL
                ELSE width IS NULL
            END
        ),
        ADD CONSTRAINT width_with_height CHECK (
            CASE
                WHEN width IS NOT NULL THEN height IS NOT NULL
                ELSE height IS NULL
            END
        ),
        ADD CONSTRAINT height_with_length CHECK (
            CASE
                WHEN height IS NOT NULL THEN length IS NOT NULL
                ELSE length IS NULL
            END
        )
    ;
    COMMENT ON COLUMN shipping_attribute.length IS 'Length of product (cm)';
    COMMENT ON COLUMN shipping_attribute.width IS 'Width of product (cm)';
    COMMENT ON COLUMN shipping_attribute.height IS 'Height of product (cm)';

COMMIT;
