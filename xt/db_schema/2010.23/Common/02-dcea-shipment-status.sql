BEGIN;

INSERT INTO shipment_item_status(id,status) SELECT MAX(id)+1,'Packing Exception' FROM shipment_item_status;

COMMIT;
