-- HKDC-366: Cannot switch on Perpetual Inventory Settings.

BEGIN WORK;

INSERT INTO public.stock_count_control (
    pick_counting,
    return_counting
) VALUES (
    false,
    false
);

COMMIT WORK;
