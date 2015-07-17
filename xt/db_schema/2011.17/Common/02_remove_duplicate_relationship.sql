BEGIN;
    ALTER TABLE country_promotion_type_welcome_pack
        DROP CONSTRAINT country_promotion_type_welcome_pack_country_id_fkey1;
COMMIT;
