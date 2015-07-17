-- country shipping charges for MRP, channel id 5
-- we're just copying what's there for channels 1 at the moment

BEGIN;

INSERT INTO public.country_shipping_charge (
    country_id, channel_id, shipping_charge_id
)
SELECT
    country_id, 5, shipping_charge_id FROM public.country_shipping_charge WHERE channel_id=1
;

COMMIT;
