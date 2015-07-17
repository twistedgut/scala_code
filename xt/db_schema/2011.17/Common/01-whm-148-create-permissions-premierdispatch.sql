-- Add Premier Dispatch auth subsection inside Fulfilment

BEGIN;

INSERT INTO authorisation_sub_section (authorisation_section_id,sub_section,ord) VALUES (
    (SELECT id FROM authorisation_section WHERE section = 'Fulfilment' ),
    'Premier Dispatch',
    (SELECT MAX(ord)+1
     FROM   authorisation_sub_section
     WHERE  authorisation_section_id = (
            SELECT  id
            FROM    authorisation_section
            WHERE   section = 'Fulfilment'
        )
    )
)
;

COMMIT;

