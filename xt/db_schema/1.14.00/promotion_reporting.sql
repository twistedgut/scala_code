-- Purpose: Linking orders & items to promotions applied in order to aid reporting
--  

BEGIN;


-- Create link table for promotion to shipment (e.g. free shipping)
create table link_shipment__promotion (
	shipment_id integer references shipment(id) not null,
	promotion varchar(255) not null,
	value numeric(10,3) not null
	);

grant all on link_shipment__promotion to www;

-- Create link table for promotion to shipment item (e.g. % off discounts)
create table link_shipment_item__promotion (
	shipment_item_id integer references shipment_item(id) not null,
	promotion varchar(255) not null,
	unit_price numeric(10,3) not null,
	tax numeric(10,3) not null,
	duty numeric(10,3) not null
	);

grant all on link_shipment_item__promotion to www;


COMMIT;