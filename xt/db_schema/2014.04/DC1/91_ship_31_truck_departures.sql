BEGIN;

    -- Update truck departures
    DELETE FROM sos.truck_departure__class;
    DELETE FROM sos.truck_departure__day;
    DELETE FROM sos.truck_departure;

    -- DHL
    INSERT INTO sos.truck_departure (carrier_id, departure_time) VALUES
        ( (SELECT id FROM sos.carrier WHERE code = 'DHL'), '07:30:00' ),
        ( (SELECT id FROM sos.carrier WHERE code = 'DHL'), '09:30:00' ),
        ( (SELECT id FROM sos.carrier WHERE code = 'DHL'), '13:00:00' ),
        ( (SELECT id FROM sos.carrier WHERE code = 'DHL'), '13:30:00' ),
        ( (SELECT id FROM sos.carrier WHERE code = 'DHL'), '15:45:00' ),
        ( (SELECT id FROM sos.carrier WHERE code = 'DHL'), '17:30:00' );

    INSERT INTO sos.truck_departure__day (day_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '07:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '17:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '07:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '17:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '07:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '17:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '07:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '17:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '07:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '17:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '07:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '09:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:00:00'
            )
        );

    -- DHL: STANDARD
    INSERT INTO sos.truck_departure__class (shipment_class_id, truck_departure_id) VALUES
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '07:30:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '09:30:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:00:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '13:30:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '15:45:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'DHL')
                AND departure_time = '17:30:00'
            )
        );

    -- NAP
    INSERT INTO sos.truck_departure (carrier_id, departure_time) VALUES
        ( (SELECT id FROM sos.carrier WHERE code = 'NAP'), '09:30:00' ),
        ( (SELECT id FROM sos.carrier WHERE code = 'NAP'), '11:45:00' ),
        ( (SELECT id FROM sos.carrier WHERE code = 'NAP'), '15:45:00' );

    INSERT INTO sos.truck_departure__day (day_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '15:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            (SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45:00'
            )
        );

    -- NAP: Premier
    INSERT INTO sos.truck_departure__class (shipment_class_id, truck_departure_id) VALUES
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '09:30:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '11:45:00'
            )
        ),
        (
            ( SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER' ),
            ( SELECT id FROM sos.truck_departure
                WHERE carrier_id = (SELECT id FROM sos.carrier WHERE code = 'NAP')
                AND departure_time = '15:45:00'
            )
        );

COMMIT;