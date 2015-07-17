-- Because we're adding a "new section" to the AppSpace, we also need to
-- add database permissions
BEGIN;

    INSERT INTO authorisation_section
    (section)
    VALUES
    ('Promotion');

    INSERT INTO authorisation_sub_section
    (authorisation_section_id, sub_section, ord)
        SELECT authorisation_section.id, 'Summary', 10
          FROM authorisation_section
         WHERE authorisation_section.section = 'Promotion'
    ;

    INSERT INTO authorisation_sub_section
    (authorisation_section_id, sub_section, ord)
        SELECT authorisation_section.id, 'Manage', 20
          FROM authorisation_section
         WHERE authorisation_section.section = 'Promotion'
    ;


    \echo Don't forget to add permissions using the Admin screen in XT!

COMMIT;
