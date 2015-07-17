BEGIN;

-- merge recode groups
-- r9452
UPDATE putaway_prep_inventory SET quantity = 14 WHERE putaway_prep_group_id = 932322;
UPDATE putaway_prep_group SET status_id = 2 where id = 932322;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 932321;
DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 932320;
DELETE FROM putaway_prep_group WHERE id = 932321;
DELETE FROM putaway_prep_group WHERE id = 932320;

-- r9446
UPDATE putaway_prep_inventory SET quantity = 9 WHERE putaway_prep_group_id = 932296;
UPDATE putaway_prep_group SET status_id = 2 where id = 932296;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 932295;
DELETE FROM putaway_prep_group WHERE id = 932295;

-- r9456
UPDATE putaway_prep_inventory SET quantity = 7 WHERE putaway_prep_group_id = 932453;
UPDATE putaway_prep_group SET status_id = 2 where id = 932453;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 932452;
DELETE FROM putaway_prep_group WHERE id = 932452;

COMMIT;
