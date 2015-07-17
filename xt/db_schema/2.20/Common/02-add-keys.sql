BEGIN;

ALTER TABLE link_shipment_item__price_adjustment ADD CONSTRAINT link_shipment_item__price_adjustment_pkey PRIMARY KEY (shipment_item_id,price_adjustment_id);

alter table carrier_box_weight add constraint carrier_box_weight_pkey primary key (id);


COMMIT;
