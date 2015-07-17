-- channelising product_type_measurement table so that we can
-- use different measurements per channel later on (MrP ME01)

BEGIN;

ALTER TABLE public.product_type_measurement 
    ADD COLUMN channel_id integer REFERENCES public.channel(id) DEFERRABLE;

ALTER TABLE public.product_type_measurement
    DROP CONSTRAINT product_type_measurement_pkey;

UPDATE public.product_type_measurement SET channel_id = (
        SELECT id FROM channel WHERE name='NET-A-PORTER.COM'
    ) WHERE channel_id IS NULL;

ALTER TABLE public.product_type_measurement
    ADD CONSTRAINT product_type_measurement_pkey PRIMARY KEY (product_type_id, measurement_id, channel_id);

INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
    SELECT ptm.product_type_id, ptm.measurement_id, c.id
    FROM public.product_type_measurement ptm, channel c, channel nap_c
    WHERE c.name='theOutnet.com'
    AND nap_c.name='NET-A-PORTER.COM'
    AND nap_c.id=ptm.channel_id;

INSERT INTO public.product_type_measurement (product_type_id, measurement_id, channel_id)
    SELECT ptm.product_type_id, ptm.measurement_id, c.id
    FROM public.product_type_measurement ptm, channel c, channel nap_c
    WHERE c.name='MrPorter.com'
    AND nap_c.name='NET-A-PORTER.COM'
    AND nap_c.id=ptm.channel_id;

COMMIT;
