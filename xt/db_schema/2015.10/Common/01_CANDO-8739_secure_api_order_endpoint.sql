-- CANDO-8739: Prevent access to the api/order endpoint unless the user
--             has the app_TEST_ONLY_INJECT_ORDERS_DO_NOT_ASSIGN_THIS_ROLE

BEGIN WORK;

--
-- Add a new Role
--
INSERT INTO acl.authorisation_role (authorisation_role) VALUES ('app_TEST_ONLY_INJECT_ORDERS_DO_NOT_ASSIGN_THIS_ROLE');

--
-- Add the URL Path
--

INSERT INTO acl.url_path (url_path) VALUES ('/api/order');

--
-- Now link the Role to the URL Path
--

INSERT INTO acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT  role.id,
            url.id
    FROM    acl.authorisation_role role,
            acl.url_path url
    WHERE   role.authorisation_role = 'app_TEST_ONLY_INJECT_ORDERS_DO_NOT_ASSIGN_THIS_ROLE'
    AND     url.url_path IN (
        '/api/order'
    )
;

COMMIT WORK;
