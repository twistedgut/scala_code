-- CANDO-3239: Assign Role for [Finance -> Transaction Reporting]

BEGIN WORK;

--
-- Add the url for Transaction Reporting page
--

INSERT INTO acl.url_path (
    url_path
) VALUES (
    '/Finance/TransactionReporting'
);


--
-- Link the Roles to the URL Paths
--

INSERT INTO  acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_canRunDatacashReport'
    AND     url.url_path IN (
        '/Finance/TransactionReporting'
);

COMMIT WORK;
