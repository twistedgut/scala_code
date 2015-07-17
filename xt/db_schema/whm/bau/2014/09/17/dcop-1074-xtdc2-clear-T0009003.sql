BEGIN;

delete from putaway_prep_inventory
    where putaway_prep_container_id = 136402;
update putaway_prep_container
    set putaway_prep_status_id = (
        select id from putaway_prep_container_status where status='Resolved'
    )
    where id = 136402;
update putaway_prep_group
    set status_id = (
        select id from putaway_prep_group_status where status='Resolved'
    )
    where id = 603657;

COMMIT;
