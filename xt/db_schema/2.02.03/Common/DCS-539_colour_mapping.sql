BEGIN;

-- adding animal print
insert into colour_filter values (30, 'Animal Print');
update filter_colour_mapping set filter_colour_id = 30 where colour_id = 91;
insert into colour_navigation values (25, 'Animal_Print');
insert into navigation_colour_mapping values (30, 25, (select id from channel where name = 'NET-A-PORTER.COM'));
insert into navigation_colour_mapping values (30, 25, (select id from channel where name = 'theOutnet.com'));
update navigation_colour_mapping set colour_navigation_id = 25 where colour_filter_id = 19 and channel_id = (select id from channel where name = 'NET-A-PORTER.COM');

-- adding pastel colours
insert into colour_filter values (31, 'Peach');
insert into colour_filter values (32, 'Blush');
insert into colour_filter values (33, 'Baby pink');
insert into colour_filter values (34, 'Pastel Orange');
insert into colour_filter values (35, 'Lilac');
insert into colour_filter values (36, 'Lavender');
insert into colour_filter values (37, 'Lemon');

insert into colour_navigation values (26, 'Pastels');

-- map colours to filter colours
update filter_colour_mapping set filter_colour_id = 31 where colour_id = (select id from colour where colour = 'Peach');
update filter_colour_mapping set filter_colour_id = 32 where colour_id = (select id from colour where colour = 'Blush');
update filter_colour_mapping set filter_colour_id = 33 where colour_id = (select id from colour where colour = 'Baby pink');
update filter_colour_mapping set filter_colour_id = 34 where colour_id = (select id from colour where colour = 'Pastel Orange');
update filter_colour_mapping set filter_colour_id = 35 where colour_id = (select id from colour where colour = 'Lilac');
update filter_colour_mapping set filter_colour_id = 36 where colour_id = (select id from colour where colour = 'Lavender');
update filter_colour_mapping set filter_colour_id = 37 where colour_id = (select id from colour where colour = 'Lemon');

-- map filter colours to nav colours
insert into navigation_colour_mapping values (31, 26, (select id from channel where name = 'NET-A-PORTER.COM'));
insert into navigation_colour_mapping values (31, 18, (select id from channel where name = 'theOutnet.com'));

insert into navigation_colour_mapping values (32, 26, (select id from channel where name = 'NET-A-PORTER.COM'));
insert into navigation_colour_mapping values (32, 17, (select id from channel where name = 'theOutnet.com'));

insert into navigation_colour_mapping values (33, 26, (select id from channel where name = 'NET-A-PORTER.COM'));
insert into navigation_colour_mapping values (33, 19, (select id from channel where name = 'theOutnet.com'));

insert into navigation_colour_mapping values (34, 26, (select id from channel where name = 'NET-A-PORTER.COM'));
insert into navigation_colour_mapping values (34, 18, (select id from channel where name = 'theOutnet.com'));

insert into navigation_colour_mapping values (35, 26, (select id from channel where name = 'NET-A-PORTER.COM'));
insert into navigation_colour_mapping values (35, 20, (select id from channel where name = 'theOutnet.com'));

insert into navigation_colour_mapping values (36, 26, (select id from channel where name = 'NET-A-PORTER.COM'));
insert into navigation_colour_mapping values (36, 20, (select id from channel where name = 'theOutnet.com'));

insert into navigation_colour_mapping values (37, 26, (select id from channel where name = 'NET-A-PORTER.COM'));
insert into navigation_colour_mapping values (37, 24, (select id from channel where name = 'theOutnet.com'));

COMMIT;