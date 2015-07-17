BEGIN;

INSERT INTO authorisation_sub_section
    (authorisation_section_id, sub_section, ord)
        SELECT authorisation_section.id, 'Pack Lanes', 60
          FROM authorisation_section
         WHERE authorisation_section.section = 'Admin'
    ;

COMMIT;
