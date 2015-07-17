-- CANDO-2790: Add a Field to 'authorisation_sub_section'
--             that allows a Main Nav option to no longer
--             be assigned to a user on the User Admin page

BEGIN WORK;

ALTER TABLE authorisation_sub_section
    ADD COLUMN acl_controlled BOOLEAN NOT NULL DEFAULT FALSE
;

COMMIT WORK;
