BEGIN;

-- adding indexes on foreign keys that we definitely definitely use

-- link_routing_export__shipment
CREATE INDEX link_routing_export__shipment_shipment_id_fkey
    ON link_routing_export__shipment(shipment_id);

CREATE INDEX link_routing_export__shipment_routing_export_id_fkey
    ON link_routing_export__shipment(routing_export_id);

-- link_manifest__shipment
CREATE INDEX link_manifest__shipment_shipment_id_fkey
    ON link_manifest__shipment(shipment_id);

CREATE INDEX link_manifest__shipment_manifest_id_fkey
    ON link_manifest__shipment(manifest_id);



COMMIT;
