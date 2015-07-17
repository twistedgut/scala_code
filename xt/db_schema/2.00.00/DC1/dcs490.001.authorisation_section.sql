-- copied from: db_schema/1.14.00/promotions_admin_permission.sql
BEGIN;

    INSERT INTO authorisation_section
    (section)
    VALUES
    ('Promotion');

    INSERT INTO authorisation_sub_section
    (authorisation_section_id, sub_section, ord)
        SELECT authorisation_section.id, 'Manage', 20
          FROM authorisation_section
         WHERE authorisation_section.section = 'Promotion'
    ;

    \echo Don't forget to add permissions using the Admin screen in XT-DC1!

COMMIT;
