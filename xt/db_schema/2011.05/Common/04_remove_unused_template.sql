BEGIN;
    DELETE FROM public.correspondence_templates
        WHERE name='Reservation Notification - Product Advisors-'
                || ( SELECT web_name FROM channel where name='MRPORTER.COM' )
    ;
COMMIT;
