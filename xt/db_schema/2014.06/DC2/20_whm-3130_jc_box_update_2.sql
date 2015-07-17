--
-- Add "JC Boot Bag"
--

BEGIN;

SELECT setval('box_id_seq', (SELECT MAX(id) FROM public.box));

-- Add Boot Bag to outer box list
INSERT INTO box (box, weight, volumetric_weight, active, channel_id) VALUES
    ('JC boot bag-XL', '0.0', '0.0', true, (SELECT id FROM channel WHERE name = 'JIMMYCHOO.COM'));

COMMIT;
