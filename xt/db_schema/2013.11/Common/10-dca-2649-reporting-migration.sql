
--
-- DCA-2649 -- New menu /Reporting/Migration
--

BEGIN WORK;


-- Create new menu item /Reporting/Migration
INSERT
    INTO authorisation_sub_section (authorisation_section_id, sub_section, ord)
    VALUES (
        ( SELECT id FROM authorisation_section WHERE SECTION = 'Reporting' ),
        'Migration',
        ( SELECT MAX(ord)+ 1 FROM authorisation_sub_section WHERE authorisation_section_id =
            ( SELECT id FROM authorisation_section WHERE section = 'Reporting' )
        )
    )
;


-- Give access to new Reporting/Migration screen to everyone who
-- already has access to Reporting/Shipping Reports
INSERT INTO operator_authorisation
    (operator_id,authorisation_sub_section_id,authorisation_level_id)
    (SELECT
        operator_id,
        (SELECT id FROM authorisation_sub_section WHERE sub_section = 'Migration'),
        (SELECT id FROM authorisation_level WHERE description = 'Read Only')
    FROM  operator_authorisation
    WHERE authorisation_sub_section_id =
        (SELECT id
            FROM authorisation_sub_section
            WHERE sub_section = 'Distribution Reports'
        )
    )
;

COMMIT;

