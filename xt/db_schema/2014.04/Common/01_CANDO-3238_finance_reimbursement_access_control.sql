--CANDO-3238 Assign Role for [Finance -> Reimbursements]

BEGIN WORK;

--
-- Add the url for Finance -> Reimbursements Page
--


INSERT INTO acl.url_path (
    url_path
) VALUES
    ('/Finance/Reimbursements'),
    ('/Finance/Reimbursements/BulkConfirm'),
    ('/Finance/Reimbursements/BulkDone')
;


--
-- Link the Roles to the URL Paths
--
INSERT INTO acl.link_authorisation_role__url_path (authorisation_role_id, url_path_id)
    SELECT role.id,
           url.id
    FROM   acl.authorisation_role role,
           acl.url_path url
    WHERE  role.authorisation_role = 'app_canCreateBulkReimbursement'
    AND    url.url_path IN (
           '/Finance/Reimbursements',
           '/Finance/Reimbursements/BulkConfirm',
           '/Finance/Reimbursements/BulkDone'
    )
;

COMMIT WORK;

