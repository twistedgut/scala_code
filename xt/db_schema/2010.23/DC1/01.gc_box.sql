-- This will add boxes for Gift Vouchers in DC1

BEGIN;

CREATE OR REPLACE FUNCTION gv_899_box()
RETURNS VOID AS $$
DECLARE
    gc_box_id INTEGER;
    gc_channel_id INTEGER;
    gc_sort_order INTEGER;

BEGIN

    SELECT id INTO gc_channel_id FROM channel where name='NET-A-PORTER.COM';

    INSERT INTO public.box (
        box,              weight, volumetric_weight, active, length, width, height, label_id, channel_id
    ) VALUES (
        'Outer GC Box',   0,      0.59,              true,   40,     29.5,  3,      16,       gc_channel_id
    ) RETURNING id INTO gc_box_id;

    SELECT max(sort_order)+1 INTO gc_sort_order FROM inner_box;

    INSERT INTO inner_box (
        inner_box,       sort_order,     active, outer_box_id, channel_id
    ) VALUES (
        'Inner GC Box',  gc_sort_order,  true,   gc_box_id,    gc_channel_id
    );
END;
$$ LANGUAGE plpgsql;

SELECT gv_899_box();
DROP FUNCTION gv_899_box();

COMMIT;
