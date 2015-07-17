-- CANDO-2198: Add System Config Settings for the
--             Welcome Pack Config Groups

BEGIN WORK;

-- NAP has packs in all languages
INSERT INTO system_config.config_group_setting ( config_group_id, setting, value )
SELECT  cg.id,
        l.code,
        'Off'
FROM    system_config.config_group cg,
        language l
WHERE   cg.name = 'Welcome_Pack'
AND     cg.channel_id IN (
    SELECT  ch.id
    FROM    channel ch
                JOIN business b ON b.id = ch.business_id
                               AND b.config_section = 'NAP'
)
ORDER BY l.id
;

-- MRP only has English packs, so use DEFAULT
INSERT INTO system_config.config_group_setting ( config_group_id, setting, value )
SELECT  cg.id,
        'DEFAULT',
        CASE cg.active
            WHEN TRUE THEN 'On'
            ELSE 'Off'
        END
FROM    system_config.config_group cg
WHERE   cg.name = 'Welcome_Pack'
AND     cg.channel_id IN (
    SELECT  ch.id
    FROM    channel ch
                JOIN business b ON b.id = ch.business_id
                               AND b.config_section = 'MRP'
)
;

--
-- Create a Log table to log changes to the above settings
--

CREATE TABLE welcome_pack_change (
    id          SERIAL NOT NULL PRIMARY KEY,
    change      CHARACTER VARYING (255) NOT NULL UNIQUE
);
ALTER TABLE welcome_pack_change OWNER TO postgres;
GRANT ALL ON TABLE welcome_pack_change TO www;
GRANT ALL ON SEQUENCE welcome_pack_change_id_seq TO www;

CREATE TABLE log_welcome_pack_change (
    id                          SERIAL NOT NULL PRIMARY KEY,
    welcome_pack_change_id      INTEGER NOT NULL REFERENCES welcome_pack_change(id),
    affected_id                 INTEGER NOT NULL,
    value                       CHARACTER VARYING (255) NOT NULL,
    operator_id                 INTEGER NOT NULL REFERENCES operator(id),
    date                        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE log_welcome_pack_change OWNER TO postgres;
GRANT ALL ON TABLE log_welcome_pack_change TO www;
GRANT ALL ON SEQUENCE log_welcome_pack_change_id_seq TO www;

-- Populate possible Welcome Pack Changes
INSERT INTO welcome_pack_change (change) VALUES
('Config Group'),
('Config Setting')
;

COMMIT WORK;
