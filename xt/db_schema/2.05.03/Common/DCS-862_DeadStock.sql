BEGIN;

INSERT INTO authorisation_sub_section VALUES (default, (SELECT id FROM authorisation_section WHERE section = 'Stock Control'), 'Dead Stock', (SELECT max(id) + 1 FROM authorisation_sub_section WHERE authorisation_section_id = (SELECT id FROM authorisation_section WHERE section = 'Stock Control')));

INSERT INTO operator_authorisation (operator_id, authorisation_sub_section_id, authorisation_level_id) (
    SELECT id, (SELECT id FROM authorisation_sub_section WHERE sub_section = 'Dead Stock'), 2 FROM operator WHERE department_id = (SELECT id FROM department WHERE department = 'Stock Control')
);


COMMIT;