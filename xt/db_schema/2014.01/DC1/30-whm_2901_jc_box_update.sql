--
-- Update box and inner_box tables with Jimmy Choo bag and gift data
--

BEGIN;

    INSERT INTO box (box, weight, volumetric_weight, active, channel_id) VALUES
        ('JC Small Bag', '0.0', '0.0', true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')),
        ('JC Medium Bag', '0.0', '0.0', true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM')),
        ('JC Large Bag', '0.0', '0.0', true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));


    INSERT INTO inner_box (inner_box, sort_order, active, channel_id, grouping_id) VALUES
        ('Jimmy Choo Book Box', 47, true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 14),
        ('Small gift', 48, true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 14),
        ('Medium gift', 49, true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 14),
        ('Large gift', 50, true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'), 14);

COMMIT;
