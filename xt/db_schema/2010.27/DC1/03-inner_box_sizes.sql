BEGIN;

---
--- Rename NAP Inner boxes
--- Correct the sort order
---
update inner_box set sort_order=1 where inner_box ilike 'No Black Box' and channel_id=1;
update inner_box set inner_box='NAP 1', sort_order=2 where inner_box ilike 'Black Box New 1' and channel_id=1;
update inner_box set inner_box='NAP 2', sort_order=3 where inner_box ilike 'Black Box New 2' and channel_id=1;
update inner_box set inner_box='NAP 3', sort_order=4 where inner_box ilike 'Black Box New 3' and channel_id=1;
update inner_box set inner_box='NAP 4', sort_order=5 where inner_box ilike 'Black Box New 4' and channel_id=1;
update inner_box set inner_box='NAP 5', sort_order=6 where inner_box ilike 'Black Box New 5' and channel_id=1;

update inner_box set inner_box='NAP BAG XS' where inner_box ilike 'Carrier Bag XS'and channel_id=1;
update inner_box set inner_box='NAP BAG S'  where inner_box ilike 'Carrier Bag S' and channel_id=1;
update inner_box set inner_box='NAP BAG M'  where inner_box ilike 'Carrier Bag M' and channel_id=1;
update inner_box set inner_box='NAP BAG L'  where inner_box ilike 'Carrier Bag L' and channel_id=1;

update inner_box set inner_box='NAP DISCREET XS' where inner_box ilike 'Brown Bag XS' and channel_id=1;
update inner_box set inner_box='NAP DISCREET S'  where inner_box ilike 'Brown Bag S'  and channel_id=1;
update inner_box set inner_box='NAP DISCREET M'  where inner_box ilike 'Brown Bag M'  and channel_id=1;
update inner_box set inner_box='NAP DISCREET L'  where inner_box ilike 'Brown Bag L'  and channel_id=1;

update inner_box set inner_box='NAP WEDDING 1' where inner_box ilike 'White Box Size 1' and channel_id=1;
update inner_box set inner_box='NAP WEDDING 2' where inner_box ilike 'White Box Size 2' and channel_id=1;
update inner_box set inner_box='NAP WEDDING 3' where inner_box ilike 'White Box Size 3' and channel_id=1;
update inner_box set inner_box='NAP WEDDING 4' where inner_box ilike 'White Box Size 4' and channel_id=1;
update inner_box set inner_box='NAP WEDDING 5' where inner_box ilike 'White Box Size 5' and channel_id=1;

---
--- Rename OutNet Inner boxes
---
update inner_box set sort_order=15 where inner_box ilike 'No Bag' and channel_id=3;
update inner_box set inner_box='ON BAG XS', sort_order=16 where inner_box ilike 'Bag XS' and channel_id=3;
update inner_box set inner_box='ON BAG S' , sort_order=17 where inner_box ilike 'Bag S'  and channel_id=3;
update inner_box set inner_box='ON BAG M' , sort_order=18 where inner_box ilike 'Bag M'  and channel_id=3;
update inner_box set inner_box='ON BAG L' , sort_order=19 where inner_box ilike 'Bag L'  and channel_id=3;

---
--- Rename MR PORTER Inner boxes
--- correct the sort order
---
update inner_box set active=false where inner_box ilike 'MRP inner box' and channel_id=5;
update inner_box set inner_box='MR P NO BAG' where inner_box ilike 'No Bag' and channel_id=5;

update inner_box set inner_box='MR P 1', sort_order=28 where inner_box ilike 'White Box Size 1'  and channel_id=5;
update inner_box set inner_box='MR P 2', sort_order=29 where inner_box ilike 'White Box Size 2'  and channel_id=5;
update inner_box set inner_box='MR P 3', sort_order=30 where inner_box ilike 'White Box Size 3'  and channel_id=5;
update inner_box set inner_box='MR P 4', sort_order=31 where inner_box ilike 'White Box Size 4'  and channel_id=5;
update inner_box set inner_box='MR P 5', sort_order=32 where inner_box ilike 'White Box Size 5'  and channel_id=5;
update inner_box set inner_box='MR P 6', sort_order=33 where inner_box ilike 'White Box Size 6'  and channel_id=5;
update inner_box set inner_box='MR P 7', sort_order=34 where inner_box ilike 'White Box Size 7'  and channel_id=5;

update inner_box set inner_box='MR P BAG XS' where inner_box ilike 'London Carrier Bag XS'  and channel_id=5;
update inner_box set inner_box='MR P BAG S'  where inner_box ilike 'London Carrier Bag S'   and channel_id=5;
update inner_box set inner_box='MR P BAG M'  where inner_box ilike 'London Carrier Bag M'   and channel_id=5;
update inner_box set inner_box='MR P BAG L'  where inner_box ilike 'London Carrier Bag L'   and channel_id=5;
update inner_box set inner_box='MR P BAG XL' where inner_box ilike 'London Carrier Bag XL'  and channel_id=5;

update inner_box set inner_box='MR P DISCREET XS' where inner_box ilike 'Discrete Carrier Bag XS'  and channel_id=5;
update inner_box set inner_box='MR P DISCREET S'  where inner_box ilike 'Discrete Carrier Bag S'   and channel_id=5;
update inner_box set inner_box='MR P DISCREET M'  where inner_box ilike 'Discrete Carrier Bag M'   and channel_id=5;
update inner_box set inner_box='MR P DISCREET L'  where inner_box ilike 'Discrete Carrier Bag L'   and channel_id=5;
update inner_box set inner_box='MR P DISCREET XL' where inner_box ilike 'Discrete Carrier Bag XL'  and channel_id=5;


COMMIT;
