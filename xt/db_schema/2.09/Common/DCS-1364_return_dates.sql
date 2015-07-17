BEGIN;

  ALTER TABLE return 
      ADD COLUMN expiry_date date,
      ADD COLUMN cancellation_date date;

COMMIT;
