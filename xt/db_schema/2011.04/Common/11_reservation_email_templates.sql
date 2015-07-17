BEGIN;

SELECT
    id,name,department_id
FROM
    public.correspondence_templates
WHERE
    name ILIKE 'Special Order Purchase Notification%'
    OR name ILIKE 'Special Order Upload Notification%'
    OR name ILIKE 'Reservation Notification%'
ORDER BY id ASC
;

UPDATE public.correspondence_templates SET
    name = 'Special Order Upload Notification-'
        || (SELECT web_name FROM public.channel WHERE business_id = 
            (SELECT id FROM public.business WHERE config_section = 'NAP'))
    WHERE name = 'Special Order Upload Notification';

UPDATE public.correspondence_templates SET
    name = 'Special Order Upload Notification - CC-'
        || (SELECT web_name FROM public.channel WHERE business_id = 
            (SELECT id FROM public.business WHERE config_section = 'NAP'))
    WHERE name = 'Special Order Upload Notification - CC';

UPDATE public.correspondence_templates SET
    name = 'Special Order Purchase Notification-'
        || (SELECT web_name FROM public.channel WHERE business_id = 
            (SELECT id FROM public.business WHERE config_section = 'NAP'))
    WHERE name = 'Special Order Purchase Notification';

UPDATE public.correspondence_templates SET
    name = 'Reservation Notification-'
        || (SELECT web_name FROM public.channel WHERE business_id = 
            (SELECT id FROM public.business WHERE config_section = 'NAP'))
    WHERE name = 'Reservation Notification';

UPDATE public.correspondence_templates SET
    name = 'Reservation Notification - Product Advisors-'
        || (SELECT web_name FROM public.channel WHERE business_id = 
            (SELECT id FROM public.business WHERE config_section = 'NAP'))
    WHERE name = 'Reservation Notification - Product Advisors';


SELECT
    id,name,department_id
FROM
    public.correspondence_templates
WHERE
    name ILIKE 'Special Order Purchase Notification%'
    OR name ILIKE 'Special Order Upload Notification%'
    OR name ILIKE 'Reservation Notification%'
ORDER BY id ASC
;

COMMIT;
