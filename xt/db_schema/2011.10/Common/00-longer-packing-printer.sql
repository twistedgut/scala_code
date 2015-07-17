BEGIN;

-- DCEA-1647

-- Make the operator_preferences accept longer packing_printer values
-- so we can use nice names

ALTER TABLE operator_preferences ALTER COLUMN packing_printer TYPE character(255);

COMMIT;
