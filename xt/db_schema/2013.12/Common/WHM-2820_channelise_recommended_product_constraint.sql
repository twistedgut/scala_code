-- Add unique indexes for CV and WIW

BEGIN;

DROP INDEX IF EXISTS uidx_recommended_product_1;

CREATE UNIQUE INDEX uidx_recommended_product_recommendation
    ON recommended_product (product_id, recommended_product_id, channel_id)
    WHERE type_id = 1 -- Recommendation (WIW)
;
CREATE UNIQUE INDEX uidx_recommended_product_colour_variation
    ON recommended_product (product_id, recommended_product_id)
    WHERE type_id = 2 -- Colour Variation
;

COMMIT;
