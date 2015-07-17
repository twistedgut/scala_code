BEGIN;

UPDATE return
    SET cancellation_date = current_timestamp,
    return_status_id = (SELECT id FROM return_status  WHERE  status = 'Cancelled')
    WHERE rma_number = 'R5063356-1887808';

COMMIT;
