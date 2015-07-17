-- Add FK to country_promotion_type_welcome_pack
BEGIN;
    ALTER TABLE country_promotion_type_welcome_pack
        ADD FOREIGN KEY (country_id) REFERENCES country;
COMMIT;
