-- http://jira/browse/DCS-695
--
-- DCS-615: create "Outnet event" page
BEGIN;
    INSERT INTO public.authorisation_section
    (id, section)
    VALUES
    (default, 'Outnet Events')
    ;

    INSERT INTO public.authorisation_sub_section
    (id, authorisation_section_id, sub_section, ord)
    VALUES (
        default,
        (SELECT id FROM public.authorisation_section WHERE section='Outnet Events'),
        'Manage',
        10
    );
COMMIT;
