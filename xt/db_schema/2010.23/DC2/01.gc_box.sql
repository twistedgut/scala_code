-- This will add boxes for Gift Vouchers in DC2

BEGIN;

CREATE OR REPLACE FUNCTION gv_899_box()
RETURNS VOID AS $$
DECLARE
    gc_box_id INTEGER;
    gc_channel_id INTEGER;
    gc_sort_order INTEGER;
    gc_carrier_id INTEGER;

BEGIN

    SELECT id INTO gc_channel_id FROM channel where name='NET-A-PORTER.COM';

    INSERT INTO public.box (
        box,            weight, volumetric_weight, active, length, width, height, label_id, channel_id
    ) VALUES (
        'Outer GC Box', 0,      1.30,              true,   15.75,  11.61, 1.18,   16,       gc_channel_id
    ) RETURNING id INTO gc_box_id;

    SELECT max(sort_order)+1 INTO gc_sort_order FROM inner_box;

    -- Set the id seq in case it's out of sync with the table
    PERFORM setval('inner_box_id_seq', (SELECT max(id) FROM inner_box));
    INSERT INTO inner_box (
        inner_box,       sort_order,     active, outer_box_id, channel_id
    ) VALUES (
        'Inner GC Box',  gc_sort_order,  true,   gc_box_id,    gc_channel_id
    );

    SELECT id INTO gc_carrier_id FROM carrier WHERE name='UPS';

    INSERT INTO carrier_box_weight (
        carrier_id, box_id, channel_id, service_name, weight
    ) VALUES (
        gc_carrier_id, gc_box_id, gc_channel_id, 'Ground', 2
    );
    INSERT INTO carrier_box_weight (
        carrier_id, box_id, channel_id, service_name, weight
    ) VALUES (
        gc_carrier_id, gc_box_id, gc_channel_id, 'Next Day Air Saver', 2
    );
    INSERT INTO carrier_box_weight (
        carrier_id, box_id, channel_id, service_name, weight
    ) VALUES (
        gc_carrier_id, gc_box_id, gc_channel_id, 'Worldwide Express Saver', 2
    );
        
END;
$$ LANGUAGE plpgsql;

SELECT gv_899_box();
DROP FUNCTION gv_899_box();

COMMIT;
