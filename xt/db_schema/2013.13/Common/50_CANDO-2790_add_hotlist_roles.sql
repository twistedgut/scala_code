-- CANDO-2790: Add Role for Finance->Fraud Hotlist page

BEGIN WORK;

--
-- Add a new Role
--
INSERT INTO acl.authorisation_role (authorisation_role) VALUES ('app_canModifyFraudHotlist');

--
-- Add all of the URL Paths used by the Hotlist page
--
INSERT INTO acl.url_path (url_path) VALUES
('/Finance/FraudHotlist'),
('/Finance/FraudHotlist/Add'),
('/Finance/FraudHotlist/Delete')
;

--
-- Now link the Roles to the URL Paths
--
INSERT INTO acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canViewFraudHotlist'
    AND     url.url_path IN (
        '/Finance/FraudHotlist'
    )
UNION
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canModifyFraudHotlist'
    AND     url.url_path IN (
        '/Finance/FraudHotlist/Add',
        '/Finance/FraudHotlist/Delete'
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
-- WHERE   sub_section = 'Fraud Hotlist'
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
--     WHERE   sub_section = 'Fraud Hotlist'
--     AND     authorisation_section_id = (
--         SELECT  id
--         FROM    authorisation_section
--         WHERE   section = 'Finance'
--     )
-- )
-- ;

COMMIT WORK;
