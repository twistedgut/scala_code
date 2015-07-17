-- CANDO-2787: Adds a Main Switch in the System Configs and
--             a Switch on the 'operator' table to indicate
--             whether to use Roles to build the Main Nav

BEGIN WORK;

--
-- Adds a new Section in the System Configs for ACL and
-- a Build Main Nav Switch to indicate whether Roles
-- should be used to build the Main Nav for Operators
-- or not
--

INSERT INTO system_config.config_group (name) VALUES ('ACL');
INSERT INTO system_config.config_group_setting ( config_group_id, setting, value )
VALUES (
    (
        SELECT  id
        FROM    system_config.config_group
        WHERE   name = 'ACL'
    ),
    'build_main_nav',
    'on'
);

--
-- Add a flag to the 'operator' table to act as a Switch
-- as to whether or not to Build the Main Nav for this
-- Operator using Roles if they have any. Default for
-- all users is FALSE (for now).
--

ALTER TABLE operator
    ADD COLUMN use_acl_for_main_nav BOOLEAN NOT NULL DEFAULT FALSE
;

COMMIT WORK;
