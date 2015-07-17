BEGIN;

    -- DHL (Standard)
    INSERT INTO sos.truck_departure (carrier_id, departure_time) VALUES
        ((SELECT id FROM sos.carrier WHERE code = 'DHL'), '12:30:00'),
        ((SELECT id FROM sos.carrier WHERE code = 'DHL'), '19:30:00');

    INSERT INTO sos.truck_departure__class (shipment_class_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '12:30:00'
            )
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '19:30:00'
            )
        );

    INSERT INTO sos.truck_departure__day (day_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '12:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '19:30:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '12:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '19:30:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '12:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '19:30:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '12:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '19:30:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '12:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '19:30:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '12:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '19:30:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '12:30:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'DHL')) AND
                departure_time = '19:30:00'
            )
        );


    -- NAP (Premier)
    INSERT INTO sos.truck_departure (carrier_id, departure_time) VALUES
        ((SELECT id FROM sos.carrier WHERE code = 'NAP'), '11:45:00'),
        ((SELECT id FROM sos.carrier WHERE code = 'NAP'), '15:45:00');

    INSERT INTO sos.truck_departure__class (shipment_class_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '15:45:00'
            )
        );

    INSERT INTO sos.truck_departure__day (day_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '15:45:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '15:45:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '15:45:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '15:45:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '11:45:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '15:45:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '11:45:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '11:45:00'
            )
        );

COMMIT;