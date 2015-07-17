BEGIN;
    UPDATE event.detail SET is_classic = true
    WHERE id IN (
        SELECT DISTINCT(event_id)
        FROM event.detail_websites
        WHERE website_id IN (
            SELECT id
            FROM event.website 
            WHERE name IN ('Intl','AM')
        )
    );
COMMIT;
