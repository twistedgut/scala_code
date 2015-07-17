
BEGIN;

UPDATE putaway_prep_inventory SET quantity = 29 WHERE id = 970063;

DELETE FROM putaway_prep_inventory WHERE id = 970062;

DELETE FROM putaway_prep_group WHERE id = 716762;

COMMIT;
