-- Add a menu entry for sticky page admin work

BEGIN;
    INSERT INTO authorisation_sub_section
        ( authorisation_section_id, sub_section, ord )
        SELECT authorisation_section.id, 'Sticky Pages', 70
            FROM authorisation_section
            WHERE section = 'Admin'
    ;
COMMIT;
