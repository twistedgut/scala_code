BEGIN;

    -- Update earliest selection times for nom-day / premier shipments
    UPDATE carrier
        SET last_pickup_daytime = '16:00:00'
        WHERE name = 'Unknown'; -- Premier

    UPDATE carrier
        SET last_pickup_daytime = '18:00:00'
        WHERE name != 'Unknown';

COMMIT;