-- make a defunct menu option not appear in access/menu
BEGIN;
    -- nuke any preferences that have this as the preferred start page
    DELETE FROM public.operator_preferences op
    WHERE default_home_page in (
        SELECT pass.id FROM public.authorisation_sub_section pass
            JOIN public.authorisation_section AS pas
                ON pass.authorisation_section_id=pas.id
        WHERE sub_section='Product Sort'
          AND     section='Admin'
    );

    -- don't leave access auth records lying about
    DELETE FROM public.operator_authorisation oa
    WHERE authorisation_sub_section_id in (
        SELECT pass.id FROM public.authorisation_sub_section pass
            JOIN public.authorisation_section AS pas
                ON pass.authorisation_section_id=pas.id
        WHERE sub_section='Product Sort'
          AND     section='Admin'
    );

    -- nuke the menu option
    DELETE FROM public.authorisation_sub_section
    WHERE id in (
        SELECT pass.id FROM public.authorisation_sub_section pass
            JOIN public.authorisation_section AS pas
                ON pass.authorisation_section_id=pas.id
        WHERE sub_section='Product Sort'
          AND     section='Admin'
    );
COMMIT;
