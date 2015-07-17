-- Add Recode permissions in the Inventory menu

BEGIN;

\set xt_section '\'Stock Control\''

INSERT INTO authorisation_sub_section (authorisation_section_id,sub_section,ord) VALUES (
    (SELECT id FROM authorisation_section WHERE section = :xt_section ),
    'Recode',
    (SELECT MAX(ord)+1
     FROM   authorisation_sub_section
     WHERE  authorisation_section_id = (
            SELECT  id
            FROM    authorisation_section
            WHERE   section = :xt_section
        )
    )
)
;

COMMIT;

