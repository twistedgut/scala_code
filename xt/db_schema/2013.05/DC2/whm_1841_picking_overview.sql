-- Give access to new Picking Overview screen to everyone in DC2 who already has access to Picking screen

BEGIN WORK;

INSERT INTO operator_authorisation (operator_id,authorisation_sub_section_id,authorisation_level_id)
       (SELECT
            operator_id,
            (SELECT id FROM authorisation_sub_section WHERE sub_section = 'Picking Overview'),
            (SELECT id FROM authorisation_level WHERE description = 'Read Only')
          FROM  operator_authorisation
          WHERE authorisation_sub_section_id =
                (SELECT id FROM authorisation_sub_section WHERE sub_section = 'Picking'));

COMMIT WORK;

