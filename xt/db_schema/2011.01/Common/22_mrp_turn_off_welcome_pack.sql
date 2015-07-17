BEGIN;

UPDATE system_config.config_group SET active = FALSE WHERE
    channel_id IN (
        SELECT id FROM public.channel WHERE business_id IN (
            SELECT id from public.business WHERE config_section = 'MRP'
        )
    ) AND name = 'Welcome_Pack';

COMMIT;
