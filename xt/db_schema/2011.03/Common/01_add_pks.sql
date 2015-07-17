BEGIN;
    ALTER TABLE link_delivery_item__quarantine_process
        ADD PRIMARY KEY (delivery_item_id, quarantine_process_id)
    ;
    ALTER TABLE link_routing_export__return
        ADD PRIMARY KEY (routing_export_id, return_id)
    ;
    ALTER TABLE link_shipment__promotion
        ADD PRIMARY KEY (shipment_id)
    ;
    ALTER TABLE link_shipment_item__promotion
        ADD PRIMARY KEY (shipment_item_id)
    ;
COMMIT;
