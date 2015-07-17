BEGIN;

update putaway_prep_container set putaway_prep_status_id = 4
where id = 123692 and container_id = 'T0010711';

COMMIT;
