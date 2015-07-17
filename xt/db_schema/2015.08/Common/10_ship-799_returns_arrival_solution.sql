-- Ticket       : SHIP-851
-- Description  : Add 2 new columns in return_delivery table to track
--                date when delivery was created and created by who

BEGIN;

ALTER TABLE return_delivery
ADD COLUMN date_created timestamp with time zone default CURRENT_TIMESTAMP;

UPDATE return_delivery
SET date_created = (SELECT date FROM return_arrival order by date desc limit 1);

ALTER TABLE return_delivery
ALTER COLUMN date_created set not null;

ALTER TABLE return_delivery
ADD COLUMN created_by integer REFERENCES operator(id) DEFERRABLE;

UPDATE return_delivery
SET created_by = (SELECT operator_id FROM return_arrival order by id desc limit 1);

ALTER TABLE return_delivery
ALTER COLUMN created_by set not null;

COMMIT;
