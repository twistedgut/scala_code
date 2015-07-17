-- Add test locations

BEGIN;
    --delete 02 locations
    DELETE FROM location_allowed_status WHERE location_id IN (SELECT id FROM location WHERE location LIKE '02%');
    DELETE FROM location WHERE location LIKE '02%';

    INSERT INTO location ( location ) VALUES ( '031A-0001A' );
    INSERT INTO location ( location ) VALUES ( '031A-0002A' );
    INSERT INTO location ( location ) VALUES ( '031A-0003A' );
    INSERT INTO location ( location ) VALUES ( '031A-0004A' );
    INSERT INTO location ( location ) VALUES ( '031A-0005A' );
    INSERT INTO location ( location ) VALUES ( '031A-0006A' );
    INSERT INTO location ( location ) VALUES ( '031A-0007A' );
    INSERT INTO location ( location ) VALUES ( '031A-0008A' );
    INSERT INTO location ( location ) VALUES ( '031A-0009A' );
    INSERT INTO location ( location ) VALUES ( '031A-0010A' );

    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0001A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0002A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0003A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0004A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0005A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0006A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0007A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0008A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0009A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );
    INSERT INTO location_allowed_status ( location_id, status_id ) VALUES (
        ( SELECT id FROM location WHERE location = '031A-0010A' ),
        ( SELECT id FROM flow.status WHERE name = 'Main Stock' )
    );

    -- remove anything location info dealing with IWS
    DELETE FROM location_allowed_status WHERE location_id = (SELECT id FROM location WHERE location = 'IWS');

    -- delete actual IWS
    DELETE FROM location WHERE location = 'IWS';

    DELETE FROM location WHERE location LIKE 'TEST%';
COMMIT;
