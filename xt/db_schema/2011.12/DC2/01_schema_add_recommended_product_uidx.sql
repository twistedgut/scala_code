-- for some reason, xtracker_dc2 was missing a unique index
-- on product_id, recommended_product_id, type_id even though
-- the xtracker db has it

BEGIN;

    CREATE UNIQUE INDEX uidx_recommended_product_1
    ON recommended_product
    USING btree (product_id, recommended_product_id, type_id);

COMMIT;

