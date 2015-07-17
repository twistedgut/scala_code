BEGIN;


-- r12422
UPDATE putaway_prep_inventory SET quantity = 11 WHERE putaway_prep_group_id = 1208222;
UPDATE putaway_prep_group SET status_id = 2 where id = 1208222;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1208223;
DELETE FROM putaway_prep_group WHERE id = 1208223;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1208224;
DELETE FROM putaway_prep_group WHERE id = 1208224;

-- r12278
UPDATE putaway_prep_inventory SET quantity = 3 WHERE putaway_prep_group_id = 1195718;
UPDATE putaway_prep_group SET status_id = 2 where id = 1195718;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1195719;
DELETE FROM putaway_prep_group WHERE id = 1195719;

-- r12276
UPDATE putaway_prep_inventory SET quantity = 3 WHERE putaway_prep_group_id = 1195711;
UPDATE putaway_prep_group SET status_id = 2 where id = 1195711;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1195712;
DELETE FROM putaway_prep_group WHERE id = 1195712;

-- r12105
UPDATE putaway_prep_inventory SET quantity = 4 WHERE putaway_prep_group_id = 1179556;
UPDATE putaway_prep_group SET status_id = 2 where id = 1179556;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1179557;
DELETE FROM putaway_prep_group WHERE id = 1179557;

-- r12081
UPDATE putaway_prep_inventory SET quantity = 11 WHERE putaway_prep_group_id = 1176933;
UPDATE putaway_prep_group SET status_id = 2 where id = 1176933;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1176934;
DELETE FROM putaway_prep_group WHERE id = 1176934;

-- r12078
UPDATE putaway_prep_inventory SET quantity = 14 WHERE putaway_prep_group_id = 1176922;
UPDATE putaway_prep_group SET status_id = 2 where id = 1176922;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1176923;
DELETE FROM putaway_prep_group WHERE id = 1176923;

-- r12024
UPDATE putaway_prep_inventory SET quantity = 6 WHERE putaway_prep_group_id = 1176072;
UPDATE putaway_prep_group SET status_id = 2 where id = 1176072;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1176073;
DELETE FROM putaway_prep_group WHERE id = 1176073;

-- r11942
UPDATE putaway_prep_inventory SET quantity = 10 WHERE putaway_prep_group_id = 1160680;
UPDATE putaway_prep_group SET status_id = 2 where id = 1160680;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1160681;
DELETE FROM putaway_prep_group WHERE id = 1160681;

-- r11816
UPDATE putaway_prep_inventory SET quantity = 7 WHERE putaway_prep_group_id = 1135300;
UPDATE putaway_prep_group SET status_id = 2 where id = 1135300;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1135301;
DELETE FROM putaway_prep_group WHERE id = 1135301;

-- r11786
UPDATE putaway_prep_inventory SET quantity = 6 WHERE putaway_prep_group_id = 1134795;
UPDATE putaway_prep_group SET status_id = 2 where id = 1134795;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1134796;
DELETE FROM putaway_prep_group WHERE id = 1134796;

-- r11789
UPDATE putaway_prep_inventory SET quantity = 2 WHERE putaway_prep_group_id = 1134800;
UPDATE putaway_prep_group SET status_id = 2 where id = 1134800;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1134801;
DELETE FROM putaway_prep_group WHERE id = 1134801;



COMMIT;
