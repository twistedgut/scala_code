-- CANDO-3389: Link the Role to the URL Paths for
--             the Order View Sidenav Fraud Rule options

BEGIN WORK;

-- Add the New Role
INSERT INTO acl.authorisation_role (authorisation_role) VALUES
('app_canTestFraudRules')
;

-- Add the new URLs
INSERT INTO acl.url_path (url_path) VALUES
('/Finance/FraudRules/Outcome'),
('/Finance/FraudRules/Test')
;

-- now link them together
INSERT INTO acl.link_authorisation_role__url_path
SELECT  acl_role.id,
        acl_url.id
FROM    acl.authorisation_role acl_role,
        acl.url_path acl_url
WHERE   acl_role.authorisation_role IN (
    'app_canTestFraudRules'
)
AND (
       acl_url.url_path = '/Finance/FraudRules/Outcome'
    OR acl_url.url_path = '/Finance/FraudRules/Test'
)
;

COMMIT WORK;
