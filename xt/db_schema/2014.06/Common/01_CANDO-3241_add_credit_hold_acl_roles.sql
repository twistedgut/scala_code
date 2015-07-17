-- CANDO-3241: Add Role for Finance->Credit Hold page

BEGIN WORK;

--
-- Add a new Role
--
INSERT INTO acl.authorisation_role (authorisation_role) VALUES ('app_canBulkReleaseCreditHold');

--
-- Add all of the URL Paths used by the Hotlist page
--
INSERT INTO acl.url_path (url_path) VALUES
('/Finance/CreditHold'),
('/Finance/CreditHold/ViewBulkActionLog'),
('/Finance/CreditHold/BulkOrderActionLog'),
('/Finance/CreditCheck/Icons')
;

--
-- Now link the Roles to the URL Paths
--
INSERT INTO acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canViewCreditHold'
    AND     url.url_path IN (
        '/Finance/CreditHold',
        '/Finance/CreditCheck/Icons'
    )
UNION
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canBulkReleaseCreditHold'
    AND     url.url_path IN (
        '/Finance/CreditHold/ViewBulkActionLog',
        '/Finance/CreditHold/BulkOrderActionLog'
    )
;

INSERT INTO acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canViewCreditCheck'
    AND     url.url_path IN (
        '/Finance/CreditCheck/Icons'
    )
;


--
-- Do the following an Iteration after Release (Request from Ben G.)
--

--
-- Stop the Hotlist page from being set in the User Admin page
--
-- UPDATE  authorisation_sub_section
--    SET acl_controlled  = TRUE
-- WHERE   sub_section = 'Credit Hold'
-- AND     authorisation_section_id = (
--     SELECT  id
--     FROM    authorisation_section
--     WHERE   section = 'Finance'
-- )
-- ;

--
-- Remove all references in 'operator_authorisation' to the Hotlist page
--
-- DELETE FROM operator_authorisation
-- WHERE   authorisation_sub_section_id = (
--     SELECT  id
--     FROM    authorisation_sub_section
--     WHERE   sub_section = 'Credit Hold'
--     AND     authorisation_section_id = (
--         SELECT  id
--         FROM    authorisation_section
--         WHERE   section = 'Finance'
--     )
-- )
-- ;

COMMIT WORK;
