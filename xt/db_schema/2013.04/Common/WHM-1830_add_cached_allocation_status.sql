-- Add a new 'cached' row to the allocation status row

BEGIN;
    SELECT setval('allocation_status_id_seq', (SELECT MAX(id) FROM public.allocation_status));
    INSERT INTO allocation_status (status, description) VALUES ('cached', 'Picked allocations that need to be induced to the pack-lane' );
COMMIT;
