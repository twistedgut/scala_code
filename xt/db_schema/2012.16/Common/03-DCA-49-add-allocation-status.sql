--
-- DCA-49 - Add allocation status
--
-- A number of bugs against DCA-49 have convinved me (PSe) that we need a real
-- allocation status. This creates it, and updates existing allocations.
--
BEGIN;

CREATE TABLE allocation_status (
    id           SERIAL NOT NULL PRIMARY KEY,
    status       VARCHAR(255) UNIQUE,
    description  TEXT NOT NULL
);
GRANT ALL ON TABLE allocation_status TO postgres;
GRANT ALL ON TABLE allocation_status TO www;
GRANT ALL ON SEQUENCE allocation_status_id_seq TO postgres;
GRANT ALL ON SEQUENCE allocation_status_id_seq TO www;

INSERT INTO allocation_status (status, description) VALUES
    ( 'requested', 'Awaiting a response from the PRL, pre-picking' ),
    ( 'allocated', 'Response received for latest msg from PRL, pre-picking' ),
    ( 'picking',   'PRL has been asked to pick this Allocate' ),
    ( 'picked',    'PRL has finished picking this Allocate');

-- Do the dance to update existing allocations...
ALTER TABLE allocation ADD COLUMN status_id INT REFERENCES allocation_status (id);
-- Set a default value
UPDATE allocation
    SET status_id = (SELECT id FROM allocation_status WHERE status = 'picking');
-- Specialize ones that shouldn't be the default value
UPDATE allocation
    SET status_id = (SELECT id FROM allocation_status WHERE status = 'allocated')
    WHERE is_open = true;
-- Make the column not null
ALTER TABLE allocation ALTER COLUMN status_id SET NOT NULL;
-- Drop old is_open
ALTER TABLE allocation DROP COLUMN is_open;

COMMIT;

