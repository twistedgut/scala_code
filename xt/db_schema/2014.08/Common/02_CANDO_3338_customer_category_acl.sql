-- CANDO-3338: Assign Role for [Customer Care -> Customer Category]

BEGIN WORK;

--
-- Add all of the URL paths used by the Customer Category page
--

INSERT INTO acl.url_path (
    url_path
) VALUES (
    '/CustomerCare/CustomerCategory'
);

--
-- Adding authorisation role for customer category
--

INSERT INTO acl.authorisation_role ( authorisation_role ) VALUES ( 'app_canModifyCustomerCategory' );

--
-- Link the roles to the URL paths
--

INSERT INTO acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE role.authorisation_role = 'app_canModifyCustomerCategory'
    AND     url.url_path IN (
        '/CustomerCare/CustomerCategory'
);

--
-- Link between authorisation role and invalid payments sub section
--

INSERT INTO acl.link_authorisation_role__authorisation_sub_section (authorisation_role_id, authorisation_sub_section_id)
    SELECT  role.id,
            sub.id
    FROM    acl.authorisation_role role,
            authorisation_sub_section sub
    WHERE   role.authorisation_role = 'app_canModifyCustomerCategory'
    AND     sub.sub_section = 'Customer Category'
;

COMMIT WORK;
