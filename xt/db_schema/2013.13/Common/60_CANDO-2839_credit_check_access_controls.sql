-- CANDO-2839: Assign Role for Finance-> Credit Check page

BEGIN WORK;

--
-- Add all of the URL Paths used by the Credit Check page
--

INSERT INTO acl.url_path (url_path) VALUES
('/Finance/CreditCheck')
;


--
-- Link the Roles to the URL Paths
--

INSERT INTO  acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canViewCreditCheck'
    AND     url.url_path IN (
        '/Finance/CreditCheck'
)
;


--
-- Do the following an Iteration after Release (Request from Ben G.)
--

--
-- Stop the Credit Check page from being set in the User Admin page
--

-- UPDATE authorisation_sub_section
--     SET acl_controlled = TRUE
-- WHERE   sub_section = 'Credit Check'
-- AND     authorisation_section_id = (
--     SELECT id
--     FROM authorisation_section
--     WHERE section = 'Finance'
-- )
-- ;


--
-- Remove all references in 'operator_authorisation' to the Credit Check page
--

-- DELETE FROM operator_authorisation
-- WHERE authorisation_sub_section_id = (
--     SELECT  id
--     FROM    authorisation_sub_section
--     WHERE   sub_section = 'Credit Check'
--     AND     authorisation_section_id = (
--         SELECT  id
--         FROM    authorisation_section
--         WHERE   section = 'Finance'
--     )
-- )
-- ;

COMMIT WORK;
