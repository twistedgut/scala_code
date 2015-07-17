-- Add FK to product_attribute(act_id)

BEGIN;
    ALTER TABLE public.product_attribute
        ADD FOREIGN KEY (act_id) REFERENCES season_act;
COMMIT;
