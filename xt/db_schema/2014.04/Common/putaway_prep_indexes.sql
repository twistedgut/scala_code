BEGIN;

create index idx__putaway_prep_inventory__putaway_prep_group_id
	on putaway_prep_inventory(putaway_prep_group_id);

create index idx__putaway_prep_inventory__putaway_prep_container_id
	on putaway_prep_inventory(putaway_prep_container_id);

create index idx__putaway_prep_inventory__variant_id
	on putaway_prep_inventory(variant_id);

create index idx__putaway_prep_inventory__voucher_variant_id
	on putaway_prep_inventory(voucher_variant_id);

create index idx__putaway_prep_group__group_id
	on putaway_prep_group(group_id);

create index idx__link_delivery_item__return_item_id
	on link_delivery_item__return_item(return_item_id);

create index idx__link_delivery_item__shipment_item__shipment_item_id
	on link_delivery_item__shipment_item(shipment_item_id);

create index idx__product__storage_type_id
	on product(storage_type_id);

create index idx__product__designer_id
	on product(designer_id);

COMMIT;
