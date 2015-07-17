-- update tables with id and last_updated columns

BEGIN;

ALTER TABLE return_arrival ADD COLUMN last_updated timestamp with time zone default now();

CREATE TRIGGER public_return_arrival_last_updated_tr
  BEFORE UPDATE
  ON "return_arrival"
  FOR EACH ROW
  EXECUTE PROCEDURE last_updated_func();


ALTER TABLE delivery ADD COLUMN last_updated timestamp with time zone default now();

CREATE TRIGGER public_delivery_last_updated_tr
  BEFORE UPDATE
  ON "delivery"
  FOR EACH ROW
  EXECUTE PROCEDURE last_updated_func();


ALTER TABLE delivery_item ADD COLUMN last_updated timestamp with time zone default now();

CREATE TRIGGER public_delivery_item_last_updated_tr
  BEFORE UPDATE
  ON "delivery_item"
  FOR EACH ROW
  EXECUTE PROCEDURE last_updated_func();


ALTER TABLE stock_process ADD COLUMN last_updated timestamp with time zone default now();

CREATE TRIGGER public_stock_process_last_updated_tr
  BEFORE UPDATE
  ON "stock_process"
  FOR EACH ROW
  EXECUTE PROCEDURE last_updated_func();


ALTER TABLE shipment_box ADD COLUMN last_updated timestamp with time zone default now();

CREATE TRIGGER public_shipment_box_last_updated_tr
  BEFORE UPDATE
  ON "shipment_box"
  FOR EACH ROW
  EXECUTE PROCEDURE last_updated_func();


ALTER TABLE putaway ADD COLUMN id serial;
GRANT ALL ON putaway_id_seq TO www;
GRANT ALL ON putaway_id_seq TO postgres;

ALTER TABLE putaway ADD COLUMN last_updated timestamp with time zone default now();

CREATE TRIGGER public_putaway_last_updated_tr
  BEFORE UPDATE
  ON "putaway"
  FOR EACH ROW
  EXECUTE PROCEDURE last_updated_func();


COMMIT;
