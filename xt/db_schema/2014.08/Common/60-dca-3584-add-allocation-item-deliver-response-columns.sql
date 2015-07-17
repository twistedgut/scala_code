BEGIN;

ALTER TABLE allocation_item ADD COLUMN delivered_at TIMESTAMP WITH TIME ZONE;
CREATE INDEX idx_allocation_item_delivered_at ON allocation_item(delivered_at);
COMMENT ON COLUMN allocation_item.delivered_at IS
'The time the PRL has told XT (in the deliver_response message) that the item
arrived at the delivery lane.';

ALTER TABLE allocation_item ADD COLUMN actual_prl_delivery_destination_id INTEGER
    REFERENCES prl_delivery_destination(id) DEFERRABLE;
CREATE INDEX idx_allocation_item_actual_prl_delivery_destination_id ON allocation_item(actual_prl_delivery_destination_id);
COMMENT ON COLUMN allocation_item.actual_prl_delivery_destination_id IS
'The destination lane that the PRL says the item was delivered to. Except in
error scenarios, this should match allocation.prl_delivery_destination_id';

CREATE SEQUENCE allocation_item_delivery_order_seq
    INCREMENT BY 1 NO MAXVALUE NO MINVALUE START WITH 1 CACHE 1;
ALTER SEQUENCE allocation_item_delivery_order_seq OWNER TO postgres;
GRANT ALL ON SEQUENCE allocation_item_delivery_order_seq TO postgres;
GRANT ALL ON SEQUENCE allocation_item_delivery_order_seq TO www;

ALTER TABLE allocation_item ADD COLUMN delivery_order INTEGER;
CREATE INDEX idx_allocation_item_delivery_order ON allocation_item(delivery_order);
COMMENT ON COLUMN allocation_item.delivery_order IS
'Value to be used to record the order in which items were delivered, in
case more than one item has the same delivered_at timestamp. To be populated
using allocation_item_delivery_order_seq according to the order the items
appear in the deliver_response message.';

COMMIT;
