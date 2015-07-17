
-- Add new auth subsection for GOH` Integration page

BEGIN;

INSERT INTO authorisation_sub_section
    (authorisation_section_id, sub_section, ord)
VALUES (
    (SELECT id FROM authorisation_section WHERE section = 'Fulfilment'),
    'GOH Integration',
    (   SELECT MAX(ord) + 1
        FROM authorisation_sub_section
        WHERE authorisation_section_id = (
            SELECT id
            FROM authorisation_section
            WHERE section = 'Fulfilment'
        )
    )
);

COMMIT;
