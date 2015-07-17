BEGIN;


INSERT INTO correspondence_templates (
    name,access,content
) VALUES (
    'Special Order Purchase Notification-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'OUTNET'))
    ,0,
    (SELECT content FROM correspondence_templates WHERE
        name = 'Special Order Purchase Notification-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'NAP'))
    )
);

INSERT INTO correspondence_templates (
    name,access,content
) VALUES (
    'Special Order Upload Notification-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'OUTNET'))
    ,0,
    (SELECT content FROM correspondence_templates WHERE
        name = 'Special Order Purchase Notification-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'NAP'))
    )
);

INSERT INTO correspondence_templates (
    name,access,content,department_id
) VALUES (
    'Special Order Upload Notification - CC-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'OUTNET'))
    ,0,
    (SELECT content FROM correspondence_templates WHERE
        name = 'Special Order Upload Notification - CC-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'NAP'))
    ),
    (SELECT department_id FROM correspondence_templates WHERE
        name = 'Special Order Upload Notification - CC-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'NAP'))
    )
);

INSERT INTO correspondence_templates (
    name,access,content
) VALUES (
    'Reservation Notification-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'OUTNET'))
    ,0,
    (SELECT content FROM correspondence_templates WHERE
        name = 'Reservation Notification-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'NAP'))
    )
);

INSERT INTO correspondence_templates (
    name,access,content,department_id
) VALUES (
    'Reservation Notification - Product Advisors-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'OUTNET'))
    ,0,
    (SELECT content FROM correspondence_templates WHERE
        name = 'Reservation Notification - Product Advisors-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'NAP'))
    ),
    (SELECT department_id FROM correspondence_templates WHERE
        name = 'Special Order Purchase Notification - Product Advisors-'
    || (SELECT web_name FROM public.channel WHERE business_id = 
        (SELECT id FROM public.business WHERE config_section = 'NAP'))
    )
);


COMMIT;
