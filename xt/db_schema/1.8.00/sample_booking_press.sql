/*****************************************************
* Sample Booking - Press Samples Changes
*  
******************************************************/
BEGIN;

-- Add 'Press Samples' location
INSERT INTO location (location, type_id) VALUES ('Press Samples', (SELECT id FROM location_type WHERE type = 'Sample'));

-- Add source_location_id, associated data, and constraints
ALTER TABLE sample_request_type ADD COLUMN source_location_id integer;

UPDATE sample_request_type SET
    source_location_id = (SELECT id FROM location WHERE location = 'Sample Room')
WHERE type IN ('Pre-Shoot', 'Editorial', 'Styling', 'Upload');

UPDATE sample_request_type SET
    source_location_id = (SELECT id FROM location WHERE location = 'Press Samples')
WHERE type = 'Press';

ALTER TABLE sample_request_type ALTER COLUMN source_location_id SET NOT NULL;
ALTER TABLE sample_request_type ADD FOREIGN KEY (source_location_id) REFERENCES location(id);

ALTER TABLE sample_request_type_operator ADD COLUMN sort_order integer;
CREATE INDEX ix_sample_request_type_operator__sort_order ON sample_request_type_operator(sort_order);


COMMIT;
