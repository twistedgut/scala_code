-- Populates the 'carrier_box_weight' table for DC2

BEGIN WORK;

-- NAP SIZES --
-- Box Size 1
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 1' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Next Day Air Saver',
2
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 1' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Worldwide Express Saver',
2
)
;
-- Box Size 2
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 2' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Next Day Air Saver',
4
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 2' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Worldwide Express Saver',
6
)
;
-- Box Size 3
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 3' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Ground',
6
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 3' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Next Day Air Saver',
6
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 3' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Worldwide Express Saver',
9
)
;
-- Box Size 4
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 4' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Ground',
13
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 4' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Next Day Air Saver',
13
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 4' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Worldwide Express Saver',
18
)
;
-- Box Size 5
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 5' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Ground',
25
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 5' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Next Day Air Saver',
25
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 5' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Worldwide Express Saver',
34
)
;
-- Box Shoe
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'SHOE BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Next Day Air Saver',
3
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'SHOE BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Worldwide Express Saver',
4
)
;
-- Box Boot
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'BOOT BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Ground',
9
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'BOOT BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Next Day Air Saver',
9
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'NAP') ON ch.id = bx.channel_id
WHERE bx.box = 'BOOT BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'NAP'),
'Worldwide Express Saver',
12
)
;

-- OUTNET SIZES --
-- Box Size 1
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 1' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Next Day Air Saver',
2
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 1' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Worldwide Express Saver',
2
)
;
-- Box Size 2
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 2' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Next Day Air Saver',
4
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 2' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Worldwide Express Saver',
6
)
;
-- Box Size 3
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 3' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Ground',
6
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 3' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Next Day Air Saver',
6
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 3' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Worldwide Express Saver',
9
)
;
-- Box Size 4
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 4' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Ground',
13
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 4' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Next Day Air Saver',
13
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 4' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Worldwide Express Saver',
18
)
;
-- Box Size 5
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 5' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Ground',
25
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 5' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Next Day Air Saver',
25
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'Box - Size 5' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Worldwide Express Saver',
34
)
;
-- Box Shoe
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'SHOE BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Next Day Air Saver',
3
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'SHOE BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Worldwide Express Saver',
4
)
;
-- Box Boot
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'BOOT BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Ground',
9
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'BOOT BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Next Day Air Saver',
9
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'BOOT BOX' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Worldwide Express Saver',
12
)
;

COMMIT WORK;

BEGIN WORK;

-- OUTNET Medium Box
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'OUTNET - Medium Box' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Next Day Air Saver',
5
)
;
INSERT INTO carrier_box_weight VALUES (
default,(SELECT id FROM carrier WHERE name = 'UPS'),
(SELECT bx.id FROM box bx JOIN (channel ch JOIN business b ON b.id = ch.business_id AND b.config_section = 'OUTNET') ON ch.id = bx.channel_id
WHERE bx.box = 'OUTNET - Medium Box' AND active = TRUE),
(SELECT ch.id FROM channel ch JOIN business b ON b.id = ch.business_id WHERE b.config_section = 'OUTNET'),
'Worldwide Express Saver',
7
)
;

COMMIT WORK;
