-- CANDO-8667: Reset Shipment 4008093 status from "Return Hold" to "Cancelled".
--
-- DC1: No
-- DC2: Yes
-- DC3: No

BEGIN WORK;

-- Create Shipment Status logs.
INSERT INTO shipment_status_log (
    shipment_id,
    shipment_status_id,
    operator_id
) VALUES (
    4008093,
    ( SELECT id FROM shipment_status WHERE status = 'Cancelled' ),
    ( SELECT id FROM operator WHERE name = 'Application' )
);

-- Insert Shipment Notes.
INSERT INTO shipment_note (
    shipment_id,
    note_type_id,
    operator_id,
    note
) VALUES (
    4008093,
    ( SELECT id FROM note_type WHERE code = 'SHP' ),
    ( SELECT id FROM operator WHERE name = 'Application' ),
    'BAU (CANDO-8667): Reset Shipment Status from "Return Hold" to "Cancelled"'
);

-- Update Shipment Status
UPDATE  shipment
SET     shipment_status_id = ( SELECT id FROM shipment_status WHERE status = 'Cancelled' )
WHERE   id = 4008093;

COMMIT WORK;
