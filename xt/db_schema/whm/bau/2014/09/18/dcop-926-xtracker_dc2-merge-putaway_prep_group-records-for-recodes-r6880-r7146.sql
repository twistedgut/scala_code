
BEGIN;

-- r6880

UPDATE putaway_prep_inventory SET quantity = 29 WHERE id = 970063;

DELETE FROM putaway_prep_inventory WHERE id = 970062;

DELETE FROM putaway_prep_group WHERE id = 716762;


-- r7146

UPDATE putaway_prep_inventory SET quantity = 14 WHERE id = 1029606;

DELETE FROM putaway_prep_inventory WHERE id in (1029604, 1029605);

DELETE FROM putaway_prep_group WHERE id in (757636, 757637);



COMMIT;
