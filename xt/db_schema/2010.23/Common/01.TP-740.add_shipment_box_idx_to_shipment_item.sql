-- TP-740: Add Shipment Box IDX to 'shipment_item' table

BEGIN WORK;

CREATE INDEX shipment_item_shipment_box_id_idx ON shipment_item (shipment_box_id)
;

COMMIT WORK;
