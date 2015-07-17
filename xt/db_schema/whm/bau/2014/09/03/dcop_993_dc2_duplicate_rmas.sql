BEGIN;

    -- Remove some duplicate RMAs
    UPDATE return
    SET cancellation_date = current_timestamp, return_status_id = (
        SELECT id
        FROM return_status
        WHERE status = 'Cancelled'
    )
    WHERE rma_number IN (
        'U2836046-1188102',
        'U2742174-1227736',
        'U3047383-1282297',
        'U3154420-1334129',
        'U3191394-1357825',
        'U3219575-1360687',
        'U3234979-1367818'
    );
COMMIT;