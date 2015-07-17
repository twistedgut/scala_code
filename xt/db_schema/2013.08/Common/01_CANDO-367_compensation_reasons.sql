-- CANDO-367: Add Renumeration Reasons
--            starting with Compensation reasons

BEGIN WORK;

--
-- Create Tables
--

CREATE TABLE renumeration_reason_type (
    id          SERIAL NOT NULL PRIMARY KEY,
    type        CHARACTER VARYING (255) NOT NULL UNIQUE
);
ALTER TABLE renumeration_reason_type OWNER TO postgres;
GRANT ALL ON TABLE renumeration_reason_type TO www;
GRANT ALL ON SEQUENCE renumeration_reason_type_id_seq TO www;

CREATE TABLE renumeration_reason (
    id                              SERIAL NOT NULL PRIMARY KEY,
    renumeration_reason_type_id     INTEGER NOT NULL REFERENCES renumeration_reason_type(id),
    reason                          CHARACTER VARYING (255) NOT NULL,
    department_id                   INTEGER REFERENCES department(id),
    UNIQUE ( renumeration_reason_type_id, reason )
);
ALTER TABLE renumeration_reason OWNER TO postgres;
GRANT ALL ON TABLE renumeration_reason TO www;
GRANT ALL ON SEQUENCE renumeration_reason_id_seq TO www;

--
-- Add 'reason_id' to Renumeration Table
--
ALTER TABLE renumeration
    ADD COLUMN renumeration_reason_id INTEGER REFERENCES renumeration_reason(id)
;

--
-- Populate Tables
--

INSERT INTO renumeration_reason_type (type) VALUES
('Compensation')
;

INSERT INTO renumeration_reason (reason,renumeration_reason_type_id,department_id) VALUES
('Faulty Item',             ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Part of PID missing',     ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Missing item from order', ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Scratched soles',         ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Damaged shoe box',        ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Stock discrepancy',       ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Shipping delay',          ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Warehouse delay',         ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Promotion codes',         ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Gift Voucher/Cards',      ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('RTV',                     ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('VOC',                     ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
('Goodwill gesture',        ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ), NULL ),
(
    'Security Credit',
    ( SELECT id FROM renumeration_reason_type WHERE type = 'Compensation' ),
    ( SELECT id FROM department WHERE department = 'Finance' )
)
;

COMMIT WORK;
