-- WHM-4562: Add Carrier Automation menu item to the 'Admin' Authorisation Section

BEGIN;

INSERT INTO authorisation_sub_section (authorisation_section_id,sub_section,ord) VALUES (
    (SELECT id FROM authorisation_section WHERE section = 'Admin'),
    'Carrier Automation',
    (SELECT MAX(ord)+10
     FROM   authorisation_sub_section
     WHERE  authorisation_section_id = (
            SELECT  id
            FROM    authorisation_section
            WHERE   section = 'Admin'
        )
    )
)
;

COMMIT;
