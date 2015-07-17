BEGIN;

update allocation set status_id = (select id from allocation_status where status = 'allocated') where id = 1032890;
update allocation_item set status_id = (select id from allocation_item_status where status = 'allocated') where allocation_id = 1032890;

COMMIT;
