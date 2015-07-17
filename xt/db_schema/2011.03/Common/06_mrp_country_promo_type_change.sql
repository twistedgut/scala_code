BEGIN;

-- its a many-to-many table and so can't have one of these as primary key
ALTER TABLE country_promotion_type_welcome_pack
    DROP CONSTRAINT country_promotion_type_welcome_pack_pkey;

-- however we can unique the two fields
ALTER TABLE country_promotion_type_welcome_pack
    ADD CONSTRAINT country_promotion_type_welcome_pack_country_id_fkey
        UNIQUE (country_id,promotion_type_id);


COMMIT;
