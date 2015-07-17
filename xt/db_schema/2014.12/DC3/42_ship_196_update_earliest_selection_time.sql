BEGIN;

    -- Update earliest selection times for nom-day / premier shipments
    UPDATE carrier
        SET last_pickup_daytime = '20:00:00'
        WHERE name = 'Unknown'; -- Premier

    UPDATE carrier
        SET last_pickup_daytime = '20:30:00'
        WHERE name != 'Unknown';

COMMIT;