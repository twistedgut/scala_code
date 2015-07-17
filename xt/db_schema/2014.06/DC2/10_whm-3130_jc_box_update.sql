--
-- Update box and inner_box tables with Jimmy Choo bag and gift data
--

BEGIN;

SELECT setval('box_id_seq', (SELECT MAX(id) FROM public.box));

INSERT INTO box (box, weight, volumetric_weight, active, channel_id) VALUES
    ('JC Small Bag', '0.0', '0.0', true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')),
    ('JC Medium Bag', '0.0', '0.0', true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')),
    ('JC Large Bag', '0.0', '0.0', true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));

SELECT setval('inner_box_id_seq', (SELECT MAX(id) FROM public.inner_box));

INSERT INTO inner_box (inner_box, sort_order, active, channel_id, grouping_id) VALUES
    ('Jimmy Choo Book Box', 46, true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 14),
    ('Small gift', 47, true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 14),
    ('Medium gift', 48, true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 14),
    ('Large gift', 49, true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 14);

COMMENT ON COLUMN box.weight IS 'Measurements are only required when box is shipped via a 3rd-party carrier';

COMMIT;
