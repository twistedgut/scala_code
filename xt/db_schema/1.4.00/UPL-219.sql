-- This patch file addresses UPL-219; http://animal/browse/UPL-219
--
-- Stylists require 'Item Damaged' in their PWL item status indication

BEGIN;

    INSERT INTO photography.sample_state
    (name, icon)
    VALUES
    ('Damaged', '/images/icons/cross.png');

COMMIT;
