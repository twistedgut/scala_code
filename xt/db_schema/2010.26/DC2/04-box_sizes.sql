BEGIN;

alter table inner_box drop constraint inner_box_sort_order_key;

---
--- New box sizes for MR PORTER
---

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 1', 0.38, 0.71, true, 22.50, 18.00, 10.50, 1,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 2', 1.14, 2.15, true, 34.30, 27.00, 13.90, 2,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 3', 1.69, 3.95, true, 41.70, 32.50, 17.50, 3,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 4', 1.78, 7.93, true, 53.70, 35.00, 25.00, 4,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 5', 2.84, 15.48, true, 67.80, 53.10, 25.80, 5,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, outer_box_id, channel_id)
values (
    'White Box size 7', 7, true,
    (SELECT currval('box_id_seq')),
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 6', 0.12, 0.86, true, 18.50, 11.00, 25.50, 6,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 7', 0.40, 0.92, true, 35.50, 16.00, 25.50, 7,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 8', 0.92, 7.16, true, 48.50, 23.00, 38.50, 8,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 9', 1.10, 11.68, true, 46.50, 23.00, 65.50, 9,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 10', 0.17, 1.69, true, 33.00, 21.50, 14.30, 10,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 11', 0.40, 5.35, true, 59.50, 36.50, 14.30, 11,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 14', 0.86, 13.99, true, 76.00, 47.00, 23.50, 14,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 15', 0.45, 3.90, true, 97.50, 20.00, 12.00, 15,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 16', 0.00, 0.59, true, 40.00, 29.50, 3.00, 16,
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 17', 0.10, 0.75, true, 23.00, 18.20, 10.80, 17,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, outer_box_id, channel_id)
values (
    'White Box size 1', 1, true,
    (SELECT currval('box_id_seq')),
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 18', 0.098, 0.92, true, 39.80, 15.00, 9.20, 18,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, outer_box_id, channel_id)
values (
    'White Box size 2', 2, true,
    (SELECT currval('box_id_seq')),
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 19', 0.16, 1.39, true, 35.00, 25.00, 95.00, 19,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, outer_box_id, channel_id)
values (
    'White Box size 3', 3, true,
    (SELECT currval('box_id_seq')),
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 20', 0.21, 2.20, true, 44.00, 30.00, 10.00, 20,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, outer_box_id, channel_id)
values (
    'White Box size 4', 4, true,
    (SELECT currval('box_id_seq')),
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 21', 0.29, 3.53, true, 44.50, 34.50, 13.80, 21,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, outer_box_id, channel_id)
values (
    'White Box size 5', 5, true,
    (SELECT currval('box_id_seq')),
    (select id from channel where web_name = 'MRP-AM')
);

insert into box (box,weight,volumetric_weight,active,length,width,height,label_id,channel_id)
values (
    'Outer 22', 0.43, 7.26, true, 54.50, 41.00, 19.50, 22,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, outer_box_id, channel_id)
values (
    'White Box size 6', 6, true,
    (SELECT currval('box_id_seq')),
    (select id from channel where web_name = 'MRP-AM')
);

insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Manhattan Carrier Bag XS', 30, true,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Manhattan Carrier Bag S', 31, true,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Manhattan Carrier Bag M', 32, true,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Manhattan Carrier Bag L', 33, true,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Manhattan Carrier Bag XL', 34, true,
    (select id from channel where web_name = 'MRP-AM')
);

insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Discrete Carrier Bag XS', 35, true,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Discrete Carrier Bag S', 36, true,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Discrete Carrier Bag M', 37, true,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Discrete Carrier Bag L', 38, true,
    (select id from channel where web_name = 'MRP-AM')
);
insert into inner_box (inner_box, sort_order, active, channel_id)
values (
    'Discrete Carrier Bag XL', 39, true,
    (select id from channel where web_name = 'MRP-AM')
);

--- update the stop-gap MR-PORTER box sizes
update inner_box set active=false where inner_box='MRP inner box';
update inner_box set inner_box='No Bag' where inner_box='MRP no box';

--- update the names of the existing NAP and OutNet outer boxes
--- this updates both NAP and Outnet (where they share a box size)

update box set box='Outer 1' where box ilike 'Box - Size 1';
update box set box='Outer 2' where box ilike 'Box - Size 2';
update box set box='Outer 3' where box ilike 'Box - Size 3';
update box set box='Outer 4' where box ilike 'Box - Size 4';
update box set box='Outer 5' where box ilike 'Box - Size 5';
update box set box='Outer 6' where box ilike 'Bag - XSmall';
update box set box='Outer 7' where box ilike 'Bag - Small';
update box set box='Outer 8' where box ilike 'Bag - Medium';
update box set box='Outer 9' where box ilike 'Bag - Large';
update box set box='Outer 10' where box ilike 'SHOE BOX';
update box set box='Outer 11' where box ilike 'BOOT BOX';
update box set box='Outer 12' where box ilike 'OUTNET - Medium Box';
update box set box='Outer 14' where box ilike 'Large Boot Box';
update box set box='Outer 15' where box ilike 'UMBRELLA';
update box set box='Outer 16' where box ilike 'Outer GC Box';

update box set active=false where box ilike 'Box - OLD Size 5';
update box set active=false where box ilike 'MRP box';

--- Ensure unique sort_order on inner_box by using the ID (items are currently in the correct order)

update inner_box set sort_order = id;

COMMIT;
