BEGIN;

-- These boxes were listed as small boxes in config for DC1, so their is_conveyable
-- and requires_tote flags are set accordingly

UPDATE box
    SET is_conveyable = FALSE, requires_tote = TRUE
    WHERE box in ('Outer 1', 'Outer 6', 'Outer 12', 'Outer 17', 'Outer 18', 'Outer 24');

-- These boxes were listed as large boxes in config for DC1, so their is_conveyable
-- and requires_tote flags are set accordingly

UPDATE box
    SET is_conveyable = FALSE, requires_tote = FALSE
    WHERE box in ('Outer 5', 'Outer 9', 'Outer 14', 'Outer 15', 'Outer 16',
                  'Outer 19', 'Outer 23', 'Outer 27', 'Outer 27A', 'Outer 27B',
                  'Outer 28', 'Outer 28A', 'Outer 29B');

COMMIT;
