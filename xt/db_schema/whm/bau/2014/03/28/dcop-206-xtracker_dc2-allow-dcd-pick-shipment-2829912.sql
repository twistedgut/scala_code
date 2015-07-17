BEGIN;

update allocation set status_id = (select id from allocation_status where status = 'picked') where id = 577637;

COMMIT;
