BEGIN;

select distinct ppg.group_id, ppg.status_id, sp.status_id, ppc.container_id, ppc.putaway_prep_status_id
from putaway_prep_group ppg join stock_process sp on ppg.group_id::int=sp.group_id
join putaway_prep_inventory ppi on ppg.id=ppi.putaway_prep_group_id
join putaway_prep_container ppc on ppc.id=ppi.putaway_prep_container_id
where sp.group_id in (2764213, 2764238, 2731205, 2499889, 2545949, 2513911, 2511181, 2447316, 2433977, 2421530, 2371446, 2357516, 2364482, 2355982, 2330507, 2201776)
order by ppg.group_id, ppc.putaway_prep_status_id;

update putaway_prep_group set status_id = (select id from putaway_prep_group_status where status = 'Completed')
where group_id::int in (2764213, 2764238, 2731205, 2499889, 2545949, 2513911, 2511181, 2447316, 2433977, 2421530, 2371446, 2357516, 2364482, 2355982, 2330507, 2201776);

update stock_process set complete = true, status_id = (select id from stock_process_status where status = 'Putaway')
where group_id in (2764213, 2764238, 2731205, 2499889, 2545949, 2513911, 2511181, 2447316, 2433977, 2421530, 2371446, 2357516, 2364482, 2355982, 2330507, 2201776);

commit;
