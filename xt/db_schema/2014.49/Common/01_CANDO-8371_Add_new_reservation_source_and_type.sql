-- CANDO-8371: Modify 'reservation_source' records and add 'reservation_type' table and populate,

BEGIN WORK;

--
-- Modify Reservation Source table
--

ALTER TABLE  reservation_source
    ADD COLUMN is_active BOOLEAN NOT NULL
    DEFAULT FALSE;
;

--
-- Re-Activate those we want to keep and
-- change their Sort Order to fit in with
-- the new sequence requested
--

UPDATE reservation_source
    SET is_active  = TRUE,
        sort_order =
            CASE source
                WHEN 'Appointment'        THEN 140
                WHEN 'Live Chat'          THEN 160
                WHEN 'LookBook'           THEN 130
                WHEN 'Sale'               THEN 210
                WHEN 'Stock Discrepancy'  THEN 200
                WHEN 'Sold Out'           THEN 150
                WHEN 'Upload Preview'     THEN 100
            END
WHERE source  IN (
    'Appointment',
    'Live Chat',
    'LookBook',
    'Sale',
    'Stock Discrepancy',
    'Sold Out',
    'Upload Preview'
);

INSERT INTO reservation_source ( source, sort_order, is_active ) VALUES
( 'Designer Preview', 110, TRUE ),
( 'Live',             120, TRUE ),
( 'Customer Request', 170, TRUE ),
( 'Escalation',       180, TRUE ),
( 'Re-order',         190, TRUE )
;


--
-- Create a Reservation Type table
--
CREATE TABLE reservation_type (
    id          SERIAL NOT NULL PRIMARY KEY,
    type        CHARACTER VARYING(255) NOT NULL UNIQUE,
    sort_order  INTEGER NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL
);

ALTER TABLE reservation_type OWNER TO postgres;
GRANT ALL ON TABLE reservation_type TO postgres;
GRANT ALL ON TABLE reservation_type TO www;

GRANT ALL ON SEQUENCE reservation_type_id_seq TO postgres;
GRANT ALL ON SEQUENCE reservation_type_id_seq TO www;

-- Populate the 'reservation_type' table
INSERT INTO reservation_type ( type, sort_order, is_active ) VALUES
( 'Appro',             10, 't' ),
( 'Pre-order Pending', 20, 't' ),
( 'Charge and Send',   30, 't' ),
( 'EIP Reservation',   40, 't' ),
( 'PS Recommendation', 50, 't' )
;


--
-- Add Column 'reservation_type_id' to 'reservation' Table
--
ALTER TABLE reservation
    ADD COLUMN reservation_type_id INTEGER REFERENCES reservation_type(id)
;



--
-- Add Column 'reservation_type_id' to  'pre_order' Table
--
ALTER TABLE pre_order
    ADD COLUMN reservation_type_id INTEGER REFERENCES reservation_type(id)
;

COMMIT WORK;
