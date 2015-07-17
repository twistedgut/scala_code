BEGIN;

-- These boxes were listed as small boxes in config for DC2, so their is_conveyable
-- and requires_tote flags are set accordingly

UPDATE box
    SET is_conveyable = FALSE, requires_tote = TRUE
    WHERE box in ('Outer 1', 'Outer 6', 'Outer 17');

-- These boxes were listed as large boxes in config for DC2, so their is_conveyable
-- and requires_tote flags are set accordingly

UPDATE box
    SET is_conveyable = FALSE, requires_tote = FALSE
    WHERE box in ('Outer 5', 'Outer 9', 'Outer 14');

COMMIT;

