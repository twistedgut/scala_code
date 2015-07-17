-- CANDO-3214: Assign Role for [Finance -> Invalid Payments]

BEGIN WORK;

--
-- Add all of the URL paths used by the Invalid Payments page
--

INSERT INTO acl.url_path (
    url_path
) VALUES (
    '/Finance/InvalidPayments'
);

--
-- Add the role
--

INSERT INTO acl.authorisation_role (
    authorisation_role
) VALUES (
    'app_canViewInvalidPayments'
);

--
-- Link the roles to the URL paths
--

INSERT INTO acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canViewInvalidPayments'
    AND     url.url_path IN (
        '/Finance/InvalidPayments'
);

--
-- Remove any current existing relationships between the sub-section and roles
--

DELETE FROM acl.link_authorisation_role__authorisation_sub_section
    WHERE authorisation_sub_section_id = (
        SELECT id 
        FROM authorisation_sub_section
        WHERE sub_section = 'Invalid Payments'
    )
;

--
-- Link between authorisation role and invalid payments sub section
--

INSERT INTO acl.link_authorisation_role__authorisation_sub_section (authorisation_role_id, authorisation_sub_section_id)
    SELECT  role.id,
            sub.id
    FROM    acl.authorisation_role role,
            authorisation_sub_section sub
    WHERE   role.authorisation_role = 'app_canViewInvalidPayments'
    AND     sub.sub_section = 'Invalid Payments'
;
    

--
-- Do the following in the iteration after this is released
--

--
-- Stop the Finance -> Invalid Payments page from being set in the User Admin page
--

--UPDATE authorisation_sub_section
--    SET acl_controlled = TRUE
--WHERE sub_section = 'Invalid Payments'
--AND authorisation_section_id = (
--    SELECT id
--    FROM authorisation_section
--    WHERE section = 'Finance'
--);

--
-- Remove all references in 'operator_authorisation' to the Invalid Payments page
--

--DELETE FROM operator_authorisation
--WHERE authorisation_sub_section_id = (
--  SELECT  id
--  FROM    authorisation_sub_section
--  WHERE   sub_section = 'Invalid Payments'
--  AND     authorisation_section_id = (
--      SELECT  id
--      FROM    authorisation_section
--      WHERE   section = 'Finance'
--  )
--);

COMMIT WORK;
