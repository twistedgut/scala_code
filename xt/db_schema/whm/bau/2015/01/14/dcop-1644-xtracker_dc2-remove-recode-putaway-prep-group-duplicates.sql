BEGIN;

-- r11448
UPDATE putaway_prep_inventory SET quantity = 4 WHERE putaway_prep_group_id = 1079414;
UPDATE putaway_prep_group SET status_id = 2 where id = 1079414;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1079415;
DELETE FROM putaway_prep_group WHERE id = 1079415;

-- r11302
UPDATE putaway_prep_inventory SET quantity = 4 WHERE putaway_prep_group_id = 1075687;
UPDATE putaway_prep_group SET status_id = 2 where id = 1075687;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1075688;
DELETE FROM putaway_prep_group WHERE id = 1075688;

-- r11282
UPDATE putaway_prep_inventory SET quantity = 8 WHERE putaway_prep_group_id = 1075548;
UPDATE putaway_prep_group SET status_id = 2 where id = 1075548;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1075549;
DELETE FROM putaway_prep_group WHERE id = 1075549;

-- r11223
UPDATE putaway_prep_inventory SET quantity = 3 WHERE putaway_prep_group_id = 1062307;
UPDATE putaway_prep_group SET status_id = 2 where id = 1062307;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1062308;
DELETE FROM putaway_prep_group WHERE id = 1062308;

-- r11150
UPDATE putaway_prep_inventory SET quantity = 8 WHERE putaway_prep_group_id = 1052120;
UPDATE putaway_prep_group SET status_id = 2 where id = 1052120;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1052121;
DELETE FROM putaway_prep_group WHERE id = 1052121;

-- r11135
UPDATE putaway_prep_inventory SET quantity = 6 WHERE putaway_prep_group_id = 1052022;
UPDATE putaway_prep_group SET status_id = 2 where id = 1052022;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1052023;
DELETE FROM putaway_prep_group WHERE id = 1052023;

-- r11030
UPDATE putaway_prep_inventory SET quantity = 3 WHERE putaway_prep_group_id = 1039120;
UPDATE putaway_prep_group SET status_id = 2 where id = 1039120;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1039121;
DELETE FROM putaway_prep_group WHERE id = 1039121;

-- r10948
UPDATE putaway_prep_inventory SET quantity = 43 WHERE putaway_prep_group_id = 1035070;
UPDATE putaway_prep_group SET status_id = 2 where id = 1035070;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 1035071;
DELETE FROM putaway_prep_group WHERE id = 1035071;

-- r10239
UPDATE putaway_prep_inventory SET quantity = 8 WHERE putaway_prep_group_id = 968255;
UPDATE putaway_prep_group SET status_id = 2 where id = 968255;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 968256;
DELETE FROM putaway_prep_group WHERE id = 968256;


COMMIT;
