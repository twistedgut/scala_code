BEGIN;

    CREATE SCHEMA sos AUTHORIZATION www;

    CREATE TABLE sos.shipment_class (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL
    );

    ALTER TABLE sos.shipment_class owner TO www;

    INSERT INTO sos.shipment_class (name) VALUES
        ('Standard'),
        ('Premier'),
        ('Staff'),
        ('Transfer')
    ;

    CREATE TABLE sos.shipment_class_attribute (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL
    );

    ALTER TABLE sos.shipment_class_attribute owner TO www;

    INSERT INTO sos.shipment_class_attribute (name) VALUES
        ('Nominated Day')
    ;

COMMIT;
