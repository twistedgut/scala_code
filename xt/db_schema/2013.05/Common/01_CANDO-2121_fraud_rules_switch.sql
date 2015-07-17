-- CANDO-2121: Fraud Rules Switch in System Config

BEGIN WORK;

-- Create a New Config Group 'Fraud Rules' per Sales Channel
INSERT INTO system_config.config_group (name,channel_id)
SELECT  'Fraud Rules',
        id
FROM    channel
ORDER BY id
;

-- Create an Engine Setting for all the 'Fraud Rules' groups and default to 'Off'
INSERT INTO system_config.config_group_setting (config_group_id,setting,value)
SELECT  cg.id,
        'Engine',
        'Off'
FROM    system_config.config_group cg
WHERE   cg.name = 'Fraud Rules'
ORDER BY cg.id
;

-- Add the new Admin Menu Option 'Fraud Rules'
INSERT INTO authorisation_sub_section (authorisation_section_id,sub_section,ord) VALUES (
    (
        SELECT  id
        FROM    authorisation_section
        WHERE   section = 'Admin'
    ),
    'Fraud Rules',
    (
        SELECT  COUNT(*) + 1
        FROM    authorisation_sub_section
        WHERE   authorisation_section_id = (
            SELECT  id
            FROM    authorisation_section
            WHERE   section = 'Admin'
        )
    )
);

COMMIT WORK;
