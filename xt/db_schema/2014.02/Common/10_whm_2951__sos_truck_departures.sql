BEGIN;

    -- These got missed out of the last one :o
    ALTER SEQUENCE sos.shipment_class_id_seq OWNER TO www;
    ALTER SEQUENCE sos.shipment_class_attribute_id_seq OWNER TO www;

    -- Add sos.carrier
    CREATE TABLE sos.carrier (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        code TEXT NOT NULL UNIQUE
    );
    ALTER TABLE sos.carrier OWNER TO www;
    ALTER SEQUENCE sos.carrier_id_seq OWNER TO www;

    INSERT INTO sos.carrier (name, code) VALUES
    --('Unknown', 'UNKNOWN'), -- Do we need this? Or something else? 'NONE'?
    ('UPS', 'UPS'),
    ('DHL', 'DHL'),
    ('NAP', 'NAP');

    -- Create a weekday table where each day is linked to the next one
    CREATE TABLE sos.week_day (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        next_day_id INT UNIQUE REFERENCES sos.week_day(id)
    );
    ALTER TABLE sos.week_day OWNER TO www;
    ALTER SEQUENCE sos.week_day_id_seq OWNER TO www;

    INSERT INTO sos.week_day (name) VALUES
        ('Monday'),
        ('Tuesday'),
        ('Wednesday'),
        ('Thursday'),
        ('Friday'),
        ('Saturday'),
        ('Sunday')
    ;
    UPDATE sos.week_day
        SET next_day_id = (SELECT id FROM sos.week_day WHERE name = 'Monday')
        WHERE id = (SELECT id FROM sos.week_day WHERE name = 'Sunday')
    ;
    UPDATE sos.week_day
        SET next_day_id = (SELECT id FROM sos.week_day WHERE name = 'Tuesday')
        WHERE id = (SELECT id FROM sos.week_day WHERE name = 'Monday')
    ;
    UPDATE sos.week_day
        SET next_day_id = (SELECT id FROM sos.week_day WHERE name = 'Wednesday')
        WHERE id = (SELECT id FROM sos.week_day WHERE name = 'Tuesday')
    ;
    UPDATE sos.week_day
        SET next_day_id = (SELECT id FROM sos.week_day WHERE name = 'Thursday')
        WHERE id = (SELECT id FROM sos.week_day WHERE name = 'Wednesday')
    ;
    UPDATE sos.week_day
        SET next_day_id = (SELECT id FROM sos.week_day WHERE name = 'Friday')
        WHERE id = (SELECT id FROM sos.week_day WHERE name = 'Thursday')
    ;
    UPDATE sos.week_day
        SET next_day_id = (SELECT id FROM sos.week_day WHERE name = 'Saturday')
        WHERE id = (SELECT id FROM sos.week_day WHERE name = 'Friday')
    ;
    UPDATE sos.week_day
        SET next_day_id = (SELECT id FROM sos.week_day WHERE name = 'Sunday')
        WHERE id = (SELECT id FROM sos.week_day WHERE name = 'Saturday')
    ;
    ALTER TABLE sos.week_day ALTER COLUMN next_day_id SET NOT NULL;

    -- Create a table that represents a single truck departure for a single carrier
    CREATE TABLE sos.truck_departure (
        id SERIAL PRIMARY KEY,
        carrier_id INT NOT NULL REFERENCES sos.carrier(id),
        departure_time TIME WITHOUT TIME ZONE NOT NULL,
        UNIQUE(carrier_id, departure_time)
    );
    ALTER TABLE sos.truck_departure OWNER TO www;
    ALTER SEQUENCE sos.truck_departure_id_seq OWNER TO www;

    -- This links to the week_day table as a many-to-many relationship
    CREATE TABLE sos.truck_departure__day (
        id SERIAL PRIMARY KEY,
        day_id INT NOT NULL REFERENCES sos.week_day(id) ON DELETE CASCADE,
        truck_departure_id INT NOT NULL REFERENCES sos.truck_departure(id) ON DELETE CASCADE,
        UNIQUE(day_id, truck_departure_id)
    );
    ALTER TABLE sos.truck_departure__day OWNER TO www;
    ALTER SEQUENCE sos.truck_departure__day_id_seq OWNER TO www;

    -- truck_departure also links to the shipment_class table as a many-to-many
    CREATE TABLE sos.truck_departure__class (
        id SERIAL PRIMARY KEY,
        shipment_class_id INT NOT NULL REFERENCES sos.shipment_class(id) ON DELETE CASCADE,
        truck_departure_id INT NOT NULL REFERENCES sos.truck_departure(id) ON DELETE CASCADE,
        UNIQUE(shipment_class_id, truck_departure_id)
    );
    ALTER TABLE sos.truck_departure__class OWNER TO www;
    ALTER SEQUENCE sos.truck_departure__class_id_seq OWNER TO www;

    -- Need a 'code' column to allow shipment classes to be identified through the future
    -- API
    ALTER TABLE sos.shipment_class ADD COLUMN api_code TEXT UNIQUE;
    UPDATE sos.shipment_class SET api_code = 'STANDARD' WHERE name = 'Standard';
    UPDATE sos.shipment_class SET api_code = 'PREMIER' WHERE name = 'Premier';
    UPDATE sos.shipment_class SET api_code = 'STAFF' WHERE name = 'Staff';
    UPDATE sos.shipment_class SET api_code = 'TRANSFER' WHERE name = 'Transfer';
    ALTER TABLE sos.shipment_class ALTER COLUMN api_code SET NOT NULL;

    -- And countries, regions and carriers...
    ALTER TABLE sos.country ADD COLUMN api_code TEXT UNIQUE NOT NULL;
    ALTER TABLE sos.region ADD COLUMN api_code TEXT UNIQUE NOT NULL;
COMMIT;
