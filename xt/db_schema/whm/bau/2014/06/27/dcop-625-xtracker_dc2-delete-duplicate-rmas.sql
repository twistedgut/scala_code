BEGIN;
-- DC2 cancel duplicate sample returns

UPDATE return
    SET cancellation_date = current_timestamp,
    return_status_id = (SELECT id FROM return_status  WHERE  status = 'Cancelled')
    WHERE rma_number in ('U2836046-1188102', 'U2742174-1227736', 'U3047383-1282297');

