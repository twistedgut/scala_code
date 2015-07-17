-- Because we're adding a "new subsection" to the AppSpace, we also need to
-- add database permissions
BEGIN;

    INSERT INTO authorisation_sub_section
    (authorisation_section_id, sub_section, ord)
        SELECT authorisation_section.id, 'Customer Class Management', 10
          FROM authorisation_section
         WHERE authorisation_section.section = 'Admin'
    ;

    \echo Don't forget to add permissions using the Admin screen in XT!

COMMIT;
