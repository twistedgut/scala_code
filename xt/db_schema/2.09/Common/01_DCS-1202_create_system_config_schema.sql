-- Create a new Schema to contain config settings for the system
-- Will create a new Schema and 2 new tables.

BEGIN WORK;

CREATE SCHEMA system_config;
GRANT ALL ON SCHEMA system_config TO postgres;
GRANT ALL ON SCHEMA system_config TO www;

CREATE TABLE system_config.config_group (
    id SERIAL NOT NULL,
    name CHARACTER VARYING(255) NOT NULL,
    channel_id INTEGER REFERENCES public.channel(id),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT config_group_pkey PRIMARY KEY(id),
    CONSTRAINT config_group_uniq UNIQUE (name,channel_id)
);
ALTER TABLE system_config.config_group OWNER TO postgres;
GRANT ALL ON TABLE system_config.config_group TO postgres;
GRANT ALL ON TABLE system_config.config_group TO www;

GRANT ALL ON TABLE system_config.config_group_id_seq TO postgres;
GRANT ALL ON TABLE system_config.config_group_id_seq TO www;

CREATE TABLE system_config.config_group_setting (
    id SERIAL NOT NULL,
    config_group_id INTEGER NOT NULL REFERENCES system_config.config_group(id),
    setting CHARACTER VARYING(255) NOT NULL,
    value TEXT,
    sequence INTEGER NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT config_group_setting_pkey PRIMARY KEY(id),
    CONSTRAINT config_group_setting_uniq UNIQUE (config_group_id,setting,sequence)
);
ALTER TABLE system_config.config_group_setting OWNER TO postgres;
GRANT ALL ON TABLE system_config.config_group_setting TO postgres;
GRANT ALL ON TABLE system_config.config_group_setting TO www;

GRANT ALL ON TABLE system_config.config_group_setting_id_seq TO postgres;
GRANT ALL ON TABLE system_config.config_group_setting_id_seq TO www;

COMMIT WORK;
