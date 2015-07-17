-- SHIP-192: Removing delete cascade constraints

BEGIN;

    ALTER TABLE sos.wms_priority
        DROP CONSTRAINT wms_priority_country_id_fkey,
        ADD CONSTRAINT wms_priority_country_id_fkey
            FOREIGN KEY (country_id)
            REFERENCES sos.country(id)
            DEFERRABLE;

    ALTER TABLE sos.wms_priority
        DROP CONSTRAINT wms_priority_region_id_fkey,
        ADD CONSTRAINT wms_priority_region_id_fkey
            FOREIGN KEY (region_id)
            REFERENCES sos.region(id)
            DEFERRABLE;

    ALTER TABLE sos.wms_priority
        DROP CONSTRAINT wms_priority_shipment_class_attribute_id_fkey,
        ADD CONSTRAINT wms_priority_shipment_class_attribute_id_fkey
            FOREIGN KEY (shipment_class_attribute_id)
            REFERENCES sos.shipment_class_attribute(id)
            DEFERRABLE;

    ALTER TABLE sos.wms_priority
        DROP CONSTRAINT wms_priority_shipment_class_id_fkey,
        ADD CONSTRAINT wms_priority_shipment_class_id_fkey
            FOREIGN KEY (shipment_class_id)
            REFERENCES sos.shipment_class(id)
            DEFERRABLE;

COMMIT;