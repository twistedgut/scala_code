-- Add premier routing data

BEGIN;

    CREATE TABLE premier_routing (
        id              integer primary key,
        description     text    not null
    );

    GRANT ALL ON premier_routing TO www;

    INSERT INTO premier_routing (id, description) VALUES
        ( 0, 'Please contact me to arrange a time' ),
        ( 1, 'Anytime before 8pm today (5:30 at weekends) - For orders placed by 1pm' ),
        ( 2, 'Within business hours (9am - 5pm) - Same day for orders placed by 10am' )
    ;

    ALTER TABLE shipment
        ADD COLUMN premier_routing_id smallint REFERENCES premier_routing(id)
    ;

    UPDATE shipment SET premier_routing_id = 0 WHERE shipment_type_id = 
        ( SELECT id FROM shipment_type WHERE type='Premier' )
    ;

COMMIT;
