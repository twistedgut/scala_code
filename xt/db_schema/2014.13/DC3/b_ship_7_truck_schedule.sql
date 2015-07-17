BEGIN;

    -- Allow flexible truck schedule including exceptions to schedule

    -- Bin old tables and start again!
    DROP TABLE sos.truck_departure__class;
    DROP TABLE sos.truck_departure__day;
    DROP TABLE sos.truck_departure;

    CREATE TABLE sos.truck_departure (
        id SERIAL PRIMARY KEY,
        begin_date DATE NOT NULL,
        end_date DATE,
        carrier_id INT NOT NULL REFERENCES sos.carrier(id),
        week_day_id INT NOT NULL REFERENCES sos.week_day(id),
        departure_time TIME WITHOUT TIME ZONE NOT NULL,
        created_datetime TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        archived_datetime TIMESTAMP WITH TIME ZONE
    );
    ALTER TABLE sos.truck_departure OWNER TO www;

    CREATE TABLE sos.truck_departure_exception (
        id SERIAL PRIMARY KEY,
        exception_date DATE NOT NULL,
        carrier_id INT NOT NULL REFERENCES sos.carrier(id),
        departure_time TIME WITHOUT TIME ZONE,
        created_datetime TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
        archived_datetime TIMESTAMP WITH TIME ZONE
    );
    ALTER TABLE sos.truck_departure_exception OWNER TO www;
    COMMENT on COLUMN sos.truck_departure_exception.departure_time
        IS 'Null value here indicates NO truck departures on this specific day';

    CREATE TABLE sos.truck_departure__shipment_class (
        id SERIAL PRIMARY KEY,
        truck_departure_id INT NOT NULL REFERENCES sos.truck_departure(id),
        shipment_class_id INT NOT NULL REFERENCES sos.shipment_class(id)
    );
    ALTER TABLE sos.truck_departure__shipment_class OWNER TO www;

    CREATE TABLE sos.truck_departure_exception__shipment_class (
        id SERIAL PRIMARY KEY,
        truck_departure_exception_id INT NOT NULL REFERENCES sos.truck_departure_exception(id),
        shipment_class_id INT NOT NULL REFERENCES sos.shipment_class(id)
    );
    ALTER TABLE sos.truck_departure_exception__shipment_class OWNER TO www;

    -- Truck schedule fitting the new structure
    INSERT INTO sos.truck_departure (
        begin_date,
        carrier_id,
        week_day_id,
        departure_time
    ) VALUES
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            '13:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            '20:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            '13:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            '20:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            '13:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            '20:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            '13:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            '20:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            '13:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            '20:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            '13:00:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            '20:00:00'
        );

    INSERT INTO sos.truck_departure__shipment_class (truck_departure_id, shipment_class_id)
        SELECT id, (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD' )
            FROM sos.truck_departure
            WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL');


    INSERT INTO sos.truck_departure (
        begin_date,
        carrier_id,
        week_day_id,
        departure_time
    ) VALUES
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            '11:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            '15:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            '11:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            '15:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            '11:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            '15:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            '11:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            '15:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            '11:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            '15:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            '11:45:00'
        ),
        (
            '01-01-2010',
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            '11:45:00'
        );

    INSERT INTO sos.truck_departure__shipment_class (truck_departure_id, shipment_class_id)
        SELECT id, (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_DAYTIME' )
            FROM sos.truck_departure
            WHERE carrier_id = (
                SELECT id FROM sos.carrier
                WHERE code = 'NAP'
                AND departure_time IN ('11:45:00')
            );
    INSERT INTO sos.truck_departure__shipment_class (truck_departure_id, shipment_class_id)
        SELECT id, (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_EVENING' )
            FROM sos.truck_departure
            WHERE carrier_id = (
                SELECT id FROM sos.carrier
                WHERE code = 'NAP'
                AND departure_time IN ('15:45:00')
            );

    INSERT INTO sos.truck_departure__shipment_class (truck_departure_id, shipment_class_id)
        SELECT id, (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER_ALL_DAY' )
            FROM sos.truck_departure
            WHERE carrier_id = (
                SELECT id FROM sos.carrier
                WHERE code = 'NAP'
                AND departure_time IN ('11:45:00', '15:45:00')
            );

COMMIT;