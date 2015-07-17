-- GV-395,GV-450: Add column 'pws_ol_id' to 'shipment_item' table to store the line id for the order line from
--                the order XML file. Also add Gift From/To/Message to shipment_item for vouchers.

BEGIN WORK;

ALTER TABLE shipment_item   ADD COLUMN pws_ol_id INTEGER,
                            ADD COLUMN gift_from TEXT,
                            ADD COLUMN gift_to TEXT,
                            ADD COLUMN gift_message TEXT
;

COMMIT WORK;
