-- CANDO-3218: Assign Role for [Finance -> Pending Invoices]

BEGIN WORK;

--
-- Add all of the URL Paths used by the Pending Invoices page
--

INSERT INTO acl.url_path (
    url_path
) VALUES (
    '/Finance/PendingInvoices'
);


--
-- Link the Roles to the URL Paths
--
-- NOTE: Using this syntax makes it easier to insert multiple roles/paths using
--       a UNION if required. See db_schema/2013.13/Common/50_CANDO-2790_add_hotlist_roles.sql
--       for an example. I chose this to be consistent with previous patches.
--

INSERT INTO  acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canViewPendingRefundsDebits'
    AND     url.url_path IN (
        '/Finance/PendingInvoices'
);


--
-- Do the following an Iteration after Release (Request from Ben G.)
--

--
-- Stop the Pending Invoices page from being set in the User Admin page
--

-- UPDATE authorisation_sub_section
--     SET acl_controlled = TRUE
-- WHERE   sub_section = 'Pending Invoices'
-- AND     authorisation_section_id = (
--     SELECT id
--     FROM authorisation_section
--     WHERE section = 'Finance'
-- )
-- ;


--
-- Remove all references in 'operator_authorisation' to the Pending Invoices page
--

-- DELETE FROM operator_authorisation
-- WHERE authorisation_sub_section_id = (
--     SELECT  id
--     FROM    authorisation_sub_section
--     WHERE   sub_section = 'Pending Invoices'
--     AND     authorisation_section_id = (
--         SELECT  id
--         FROM    authorisation_section
--         WHERE   section = 'Finance'
--     )
-- )
-- ;

COMMIT WORK;
