-- Set nullable foreign keys for country_id and operator_id

BEGIN;

    -- Set old Serbia and Montenegro products to Serbia
    UPDATE shipping_attribute
        SET country_id = 185
            WHERE country_id = 72
    ;

    -- Set country_id with 0 to null
    UPDATE shipping_attribute
        SET country_id = NULL
            WHERE country_id = 0
    ;

    -- Set non-existent operators to 1
    UPDATE shipping_attribute
        SET operator_id = 1
            WHERE operator_id NOT IN (
                SELECT id FROM operator
            )
    ;

    ALTER TABLE shipping_attribute
        ADD FOREIGN KEY
            (country_id) REFERENCES country(id)
    ;

    ALTER TABLE shipping_attribute
        ADD FOREIGN KEY
            (operator_id) REFERENCES operator(id)
    ;

COMMIT;
