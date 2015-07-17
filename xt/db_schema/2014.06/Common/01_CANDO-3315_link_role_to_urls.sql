-- CANDO-3315: Link the Role to the URL Paths for
--             Accepting, Credit Hold & Credit Check

BEGIN WORK;

-- Add the New Role
INSERT INTO acl.authorisation_role (authorisation_role) VALUES
('app_canProcessCreditHoldCheck')
;

-- Add the new URLs
INSERT INTO acl.url_path (url_path) VALUES
('/Finance/Order/CreditHold'),
('/Finance/Order/CreditCheck'),
('/Finance/Order/Accept')
;

-- now link them together
INSERT INTO acl.link_authorisation_role__url_path
SELECT  acl_role.id,
        acl_url.id
FROM    acl.authorisation_role acl_role,
        acl.url_path acl_url
WHERE   acl_role.authorisation_role IN (
    'app_canProcessCreditHoldCheck'
)
AND (
       acl_url.url_path = '/Finance/Order/CreditHold'
    OR acl_url.url_path = '/Finance/Order/CreditCheck'
    OR acl_url.url_path = '/Finance/Order/Accept'
)
;

COMMIT WORK;
