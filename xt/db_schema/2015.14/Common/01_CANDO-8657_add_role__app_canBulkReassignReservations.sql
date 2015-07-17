-- CANDO-8657: Add the new role: app_canBulkReassignReservations

BEGIN WORK;

-- Add the role.
INSERT INTO acl.authorisation_role (
    authorisation_role
) VALUES (
    'app_canBulkReassignReservations'
);

-- Add the URLs for the page and API.
INSERT INTO acl.url_path (
    url_path
) VALUES
    ( '/StockControl/Reservation/BulkReassign' ),
    ( '/API/StockControl/Reservation/Reassign' );

-- Link the role to the URLs.
INSERT INTO acl.link_authorisation_role__url_path (
    authorisation_role_id,
    url_path_id
) VALUES
    (
        (
            SELECT  id
            FROM    acl.authorisation_role
            WHERE   authorisation_role = 'app_canBulkReassignReservations'
        ), (
            SELECT  id
            FROM    acl.url_path
            WHERE   url_path = '/StockControl/Reservation/BulkReassign'
        )
    ), (
        (
            SELECT  id
            FROM    acl.authorisation_role
            WHERE   authorisation_role = 'app_canBulkReassignReservations'
        ), (
            SELECT  id
            FROM    acl.url_path
            WHERE   url_path = '/API/StockControl/Reservation/Reassign'
        )
    );

COMMIT;
