BEGIN WORK;


CREATE TABLE link_orders__pre_order (
    orders_id           INTEGER NOT NULL REFERENCES orders(id),
    pre_order_id        INTEGER NOT NULL REFERENCES pre_order(id)
);

ALTER TABLE link_orders__pre_order OWNER            TO postgres;
GRANT ALL ON TABLE link_orders__pre_order           TO postgres;
GRANT ALL ON TABLE link_orders__pre_order           TO www;

CREATE INDEX link_orders__pre_order__orders_idx    ON link_orders__pre_order(orders_id);
CREATE INDEX link_orders__pre_order__pre_order_idx ON link_orders__pre_order(pre_order_id);

ALTER TABLE link_orders__pre_order ADD CONSTRAINT link_orders__pre_order__unique_ref UNIQUE (orders_id, pre_order_id);

CREATE TABLE link_shipment_item__reservation (
    shipment_item_id    INTEGER NOT NULL REFERENCES shipment_item(id),
    reservation_id      INTEGER NOT NULL REFERENCES reservation(id)
);

ALTER TABLE link_shipment_item__reservation OWNER            TO postgres;
GRANT ALL ON TABLE link_shipment_item__reservation           TO postgres;
GRANT ALL ON TABLE link_shipment_item__reservation           TO www;

CREATE INDEX link_shipment_item__reservation__shipment_item_idx    ON link_shipment_item__reservation(shipment_item_id);
CREATE INDEX link_shipment_item__reservation__reservation_idx      ON link_shipment_item__reservation(reservation_id);

ALTER TABLE link_shipment_item__reservation ADD CONSTRAINT link_shipment_item__reservation__unique_ref UNIQUE (shipment_item_id, reservation_id);

COMMIT WORK;
