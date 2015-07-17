--CANDO-3220 Assign Role for [Admin -> Fraud Rules]

BEGIN WORK;

--
-- Add the url for Transaction Reporting Page
--


INSERT INTO acl.url_path (
    url_path
) VALUES (
    '/Admin/FraudRules'
);


--
-- Link the Roles to the URL Paths
--
INSERT INTO acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT role.id,
           url.id
    FROM   acl.authorisation_role role,
           acl.url_path url
    WHERE  role.authorisation_role = 'app_canManageFraudRuleSettings'
    AND    url.url_path IN (
           '/Admin/FraudRules'
);

COMMIT WORK;
