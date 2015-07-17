-- Change the 'return_arrival' table, rename column rto to removed,
-- add a return_removal_reason id and a removal notes field

BEGIN WORK;

ALTER TABLE return_arrival RENAME rto TO removed;
ALTER TABLE return_arrival ADD COLUMN return_removal_reason_id INTEGER;
ALTER TABLE return_arrival ADD COLUMN removal_notes TEXT;
ALTER TABLE return_arrival ADD CONSTRAINT return_removal_reason_fkey FOREIGN KEY (return_removal_reason_id) REFERENCES return_removal_reason(id);

-- Populate new return_removal_reason_id column with value for 'RTO' for all records
-- with removed (rto) column set to true

UPDATE return_arrival
	SET return_removal_reason_id = (
					SELECT	id
					FROM	return_removal_reason
					WHERE	name = 'RTO'
				)
WHERE removed = TRUE
;

COMMIT WORK;
