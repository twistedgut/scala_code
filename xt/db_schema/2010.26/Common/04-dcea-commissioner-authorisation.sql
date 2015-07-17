BEGIN;


INSERT INTO authorisation_sub_section (authorisation_section_id, sub_section, ord)
     VALUES (
                (SELECT id FROM authorisation_section WHERE section = 'Fulfilment'), 
                'Commissioner', 
                (SELECT MAX(ord) + 1 FROM authorisation_sub_section 
                  WHERE authorisation_section_id 
                            = (SELECT id FROM authorisation_section WHERE section = 'Fulfilment')
                )
);

INSERT INTO operator_authorisation (operator_id, authorisation_sub_section_id, authorisation_level_id) 
     VALUES (
                (SELECT id FROM operator where username='it.god'),
                (SELECT id FROM authorisation_sub_section WHERE sub_section='Commissioner'), 
                (SELECT id FROM authorisation_level WHERE description = 'Manager')
);

COMMIT;

