BEGIN;

INSERT INTO inner_box VALUES (default, 'Bag XS', 15, true, 21, (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO inner_box VALUES (default, 'Bag S', 16, true, 22, (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO inner_box VALUES (default, 'Bag M', 17, true, 23, (SELECT id FROM channel WHERE name = 'The Outnet'));
INSERT INTO inner_box VALUES (default, 'Bag L', 18, true, 24, (SELECT id FROM channel WHERE name = 'The Outnet'));

SELECT setval('box_id_seq', (SELECT max(id) + 1 FROM box));

INSERT INTO box (box, weight, volumetric_weight, active, length, width, height, label_id, channel_id) SELECT box, weight, volumetric_weight, active, length, width, height, label_id, (SELECT id FROM channel WHERE name = 'The Outnet') FROM box WHERE box in ('Box - Size 1','Box - Size 2','Box - Size 3','Box - Size 4','Box - Size 5','Bag - XSmall', 'Bag - Small', 'Bag - Medium', 'Bag - Large', 'SHOE BOX', 'BOOT BOX');

INSERT INTO box (box, weight, volumetric_weight, active, length, width, height, label_id, channel_id) VALUES ( 'OUTNET - Medium Box', 0.372, 3.17, true, 45.5, 38, 11, 12, (SELECT id FROM channel WHERE name = 'The Outnet'));

COMMIT;