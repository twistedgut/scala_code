BEGIN;
    select setval('inner_box_id_seq', (select max(id) from inner_box));
    insert into inner_box (inner_box, sort_order, active, outer_box_id) values ('Brown Bag XS', 11, true, 21);
    insert into inner_box (inner_box, sort_order, active, outer_box_id) values ('Brown Bag S', 12, true, 22);
    insert into inner_box (inner_box, sort_order, active, outer_box_id) values ('Brown Bag M', 13, true, 23);
    insert into inner_box (inner_box, sort_order, active, outer_box_id) values ('Brown Bag L', 14, true, 24);
COMMIT;
