BEGIN;

    CREATE TABLE sos.nominated_day_selection_time (
        id SERIAL PRIMARY KEY,
        carrier_id INT NOT NULL REFERENCES sos.carrier(id) ON DELETE CASCADE,
        shipment_class_id INT NOT NULL REFERENCES sos.shipment_class(id) ON DELETE CASCADE,
        selection_time TIME NOT NULL,
        UNIQUE (carrier_id, shipment_class_id)
    );
    GRANT ALL ON TABLE sos.nominated_day_selection_time TO www;
    GRANT USAGE ON SEQUENCE sos.nominated_day_selection_time_id_seq TO www;

    INSERT INTO sos.nominated_day_selection_time (carrier_id, shipment_class_id, selection_time) VALUES
        (
            (SELECT id FROM sos.carrier WHERE code = 'UPS'),
            (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD'),
            (SELECT last_pickup_daytime FROM carrier WHERE name = 'UPS')
        ),
        (
            (SELECT id FROM sos.carrier WHERE code = 'DHL'),
            (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD'),
            (SELECT last_pickup_daytime FROM carrier WHERE name = 'DHL Express')
        ),
        (
            (SELECT id FROM sos.carrier WHERE code = 'NAP'),
            (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER'),
            (SELECT last_pickup_daytime FROM carrier WHERE name = 'Unknown')
        );

    ALTER TABLE sos.processing_time DROP COLUMN processing_time;
    ALTER TABLE sos.processing_time ADD COLUMN processing_time INTERVAL NOT NULL;

    -- Add default country data (Copied from XT)
    INSERT INTO sos.country (name, api_code)
        SELECT country, code FROM country WHERE country != 'Unknown'
    ;

    -- Nigeria isn't in the db yet, but we'll add the 'special country' entry now
    INSERT INTO sos.country (name, api_code) VALUES
        ('Nigeria', 'NG')
    ;

    -- Add processing times
    INSERT INTO sos.processing_time (class_id, country_id, region_id, class_attribute_id, processing_time) VALUES
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'STANDARD'), NULL, NULL, NULL, '03:00:00' ),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'PREMIER'), NULL, NULL, NULL, '02:00:00' ),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'STAFF'), NULL, NULL, NULL, '168:00:00' ),
        ( (SELECT id FROM sos.shipment_class WHERE api_code = 'TRANSFER'), NULL, NULL, NULL, '24:00:00' ),
        ( NULL, NULL, NULL, (SELECT id FROM sos.shipment_class_attribute WHERE name = 'Nominated Day'), '02:00:00' ),
        -- 'Special' countries
        (NULL, (SELECT id FROM sos.country WHERE api_code = 'AU'), NULL, NULL, '01:00:00'),
        (NULL, (SELECT id FROM sos.country WHERE api_code = 'AR'), NULL, NULL, '01:00:00'),
        (NULL, (SELECT id FROM sos.country WHERE api_code = 'BH'), NULL, NULL, '01:00:00'),
        (NULL, (SELECT id FROM sos.country WHERE api_code = 'NG'), NULL, NULL, '01:00:00'),
        (NULL, (SELECT id FROM sos.country WHERE api_code = 'ZA'), NULL, NULL, '01:00:00'),
        (NULL, (SELECT id FROM sos.country WHERE api_code = 'AE'), NULL, NULL, '01:00:00');

    -- Transfer and Staff (NAP) truck departures are fake ones that are the same across DCs
    INSERT INTO sos.truck_departure (carrier_id, departure_time) VALUES
        ((SELECT id FROM sos.carrier WHERE code = 'NAP'), '08:00:00'),
        ((SELECT id FROM sos.carrier WHERE code = 'NAP'), '12:00:00'),
        ((SELECT id FROM sos.carrier WHERE code = 'NAP'), '14:00:00'),
        ((SELECT id FROM sos.carrier WHERE code = 'NAP'), '16:00:00');

    INSERT INTO sos.truck_departure__class (shipment_class_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'TRANSFER'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '08:00:00'
            )
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'TRANSFER'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '12:00:00'
            )
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'STAFF'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '14:00:00'
            )
        ),
        (
            (SELECT id FROM sos.shipment_class WHERE api_code = 'TRANSFER'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '16:00:00'
            )
        );

    INSERT INTO sos.truck_departure__day (day_id, truck_departure_id) VALUES
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '08:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '12:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '16:00:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '08:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '12:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '16:00:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '08:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '12:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '16:00:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '08:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '12:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '16:00:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '08:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '12:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '16:00:00'
            )
        ),

        (
            (SELECT id FROM sos.week_day WHERE name = 'Monday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '14:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Tuesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '14:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Wednesday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '14:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Thursday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '14:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Friday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '14:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Saturday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '14:00:00'
            )
        ),
        (
            (SELECT id FROM sos.week_day WHERE name = 'Sunday'),
            (SELECT id FROM sos.truck_departure WHERE
                carrier_id = ((SELECT id FROM sos.carrier WHERE code = 'NAP')) AND
                departure_time = '14:00:00'
            )
        );

COMMIT;
