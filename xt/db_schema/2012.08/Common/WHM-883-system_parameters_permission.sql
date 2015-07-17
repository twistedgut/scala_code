-- Add a menu entry for system parameters screen

BEGIN;
    INSERT INTO authorisation_sub_section ( sub_section, authorisation_section_id, ord )
    VALUES (
        'System Parameters',
        -- add to Admin menu
        (
            SELECT id
            FROM authorisation_section
            WHERE section = 'Admin'
        ),
        -- add after last item on Admin menu
        (
            SELECT MAX(ord)+1
            FROM authorisation_sub_section
            WHERE authorisation_section_id = (
                SELECT id
                FROM authorisation_section
                WHERE section = 'Admin'
            )
        )
    );
COMMIT;

