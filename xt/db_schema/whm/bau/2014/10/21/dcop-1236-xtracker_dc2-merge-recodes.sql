BEGIN;

-- merge recode groups
-- r8365
UPDATE putaway_prep_inventory SET quantity = 13 WHERE putaway_prep_group_id = 872412;
UPDATE putaway_prep_group SET status_id = 2 where id = 872412;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 872411;
DELETE FROM putaway_prep_group WHERE id = 872411;

-- r8316
UPDATE putaway_prep_inventory SET quantity = 30 WHERE putaway_prep_group_id = 869648;
UPDATE putaway_prep_group SET status_id = 2 where id = 869648;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 869647;
DELETE FROM putaway_prep_group WHERE id = 869647;

-- r8299
UPDATE putaway_prep_inventory SET quantity = 3 WHERE putaway_prep_group_id = 869139;
UPDATE putaway_prep_group SET status_id = 2 where id = 869139;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 869138;
DELETE FROM putaway_prep_group WHERE id = 869138;

-- r8264
UPDATE putaway_prep_inventory SET quantity = 4 WHERE putaway_prep_group_id = 866958;
UPDATE putaway_prep_group SET status_id = 2 where id = 866958;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 866957;
DELETE FROM putaway_prep_group WHERE id = 866957;

-- r8116
UPDATE putaway_prep_inventory SET quantity = 15 WHERE putaway_prep_group_id = 855791;
UPDATE putaway_prep_group SET status_id = 2 where id = 855791;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 855790;
DELETE FROM putaway_prep_group WHERE id = 855790;

-- r6858
UPDATE putaway_prep_inventory SET quantity = 10 WHERE putaway_prep_group_id = 716708;
UPDATE putaway_prep_group SET status_id = 2 where id = 716708;

DELETE FROM putaway_prep_inventory WHERE putaway_prep_group_id = 716707;
DELETE FROM putaway_prep_group WHERE id = 716707;


-- clean up records left from previous merge (currently showing as complete)
-- r6880
UPDATE putaway_prep_group SET status_id = 2 where id = 970063;

-- r7146
UPDATE putaway_prep_group SET status_id = 2 where id = 1029606;

COMMIT;
