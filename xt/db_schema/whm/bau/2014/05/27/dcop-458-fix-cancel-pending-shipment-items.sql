BEGIN;

-- DCOP-458: Munge a list of SKUs and PIDs into a list of Shipment Item IDs
CREATE TEMPORARY TABLE shipment_item_ids_to_fix AS
SELECT si.id FROM shipment_item si
JOIN shipment_item_status sis ON (si.shipment_item_status_id = sis.id)
JOIN variant v ON (si.variant_id = v.id)
WHERE sis.status = 'Cancel Pending'
AND (
    (v.product_id || '-' || sku_padding(v.size_id) = '407401-097' AND shipment_id = '2953224') OR
    (v.product_id || '-' || sku_padding(v.size_id) = '342312-089' AND shipment_id = '2953396') OR
    (v.product_id || '-' || sku_padding(v.size_id) = '460076-012' AND shipment_id = '2953147') OR
    (v.product_id || '-' || sku_padding(v.size_id) = '438544-014' AND shipment_id = '2953799') OR
    (v.product_id || '-' || sku_padding(v.size_id) = '433008-011' AND shipment_id = '2953147') OR
    (v.product_id || '-' || sku_padding(v.size_id) = '422452-012' AND shipment_id = '2954975') OR
    (v.product_id || '-' || sku_padding(v.size_id) = '462401-012' AND shipment_id = '2953147') OR
    (v.product_id || '-' || sku_padding(v.size_id) = '418212-035' AND shipment_id = '2764228')
);

-- Do the standard fix, copied from WOPS-989
update shipment_item
set shipment_item_status_id = (select id from shipment_item_status where status = 'Cancelled')
where
    shipment_item_status_id = (select id from shipment_item_status where status = 'Cancel Pending')
    and id in (
        select id from shipment_item_ids_to_fix
    )
;

COMMIT;
