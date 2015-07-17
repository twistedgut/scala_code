-- CANDO-2910: Add new Hold Reasons and a new flag on
--             the 'shipment_hold_reason' table called
--             'manually_releasable' & an 'information'
--             field to give the Operators info about
--             the Hold Reason.

BEGIN WORK;

--
-- Add the new column
--
ALTER TABLE shipment_hold_reason
    ADD COLUMN manually_releasable BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN information TEXT
;


--
-- Add new Reasons
--
INSERT INTO shipment_hold_reason (reason,manually_releasable,information) VALUES
(
    'Credit Hold - subject to external payment review',
    FALSE,
    'The Shipment has been placed on Hold because we are awaiting confirmation about the payment from an External Payment provider. ' ||
    'Because of this the Shipment can''t be released manually and will only be released once the External Payment provider has approved the payment.'
),
(
    'External payment failed',
    FALSE,
    'The Shipment has been placed on Hold because the External Payment provider did not approve the payment. ' ||
    'Because of this the Shipment can''t be released until a new Pre-Auth has been obtained.'
)
;

COMMIT WORK;
