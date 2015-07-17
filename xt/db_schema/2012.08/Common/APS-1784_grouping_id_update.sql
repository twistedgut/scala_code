BEGIN;

alter table inner_box add grouping_id integer;
update inner_box set grouping_id = 1 where id in (6);
update inner_box set grouping_id = 2 where id in (1,2,3,4,5);
update inner_box set grouping_id = 3 where id in (7,8,9,10);
update inner_box set grouping_id = 4 where id in (11,12,13,14);
update inner_box set grouping_id = 5 where id in (20,21,22,23,24);
update inner_box set grouping_id = 6 where id in (28);
update inner_box set grouping_id = 7 where id in (19);
update inner_box set grouping_id = 8 where id in (15,16,17,18);
update inner_box set grouping_id = 9 where id in (26,27);
update inner_box set grouping_id = 10 where id in (30,31,32,33,34,35,29,47);
update inner_box set grouping_id = 11 where id in (36,37,38,39,40);
update inner_box set grouping_id = 12 where id in (41,42,43,44,45);
update inner_box set grouping_id = 13 where id in (46);

COMMIT;
