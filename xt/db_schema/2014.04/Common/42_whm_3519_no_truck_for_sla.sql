BEGIN;

    -- Shipment classes in SOS can be configured to use truck departure times for SLAs
    -- (or not)
    ALTER TABLE sos.shipment_class ADD COLUMN use_truck_departure_times_for_sla BOOLEAN NOT NULL DEFAULT true;

    UPDATE sos.shipment_class SET use_truck_departure_times_for_sla = false
        WHERE name IN ('Staff', 'Transfer');

    -- Remove the fake truck times for these shipment_classes
    DELETE FROM sos.truck_departure WHERE id IN (
        SELECT truck_departure_id
        FROM sos.truck_departure__class
        WHERE truck_departure_id IN (
            SELECT truck_departure_id
            FROM sos.truck_departure__class
            WHERE shipment_class_id IN (
                SELECT id
                FROM sos.shipment_class
                WHERE use_truck_departure_times_for_sla = false
            )
        )
        AND truck_departure_id NOT IN (
            SELECT truck_departure_id
            FROM sos.truck_departure__class
            WHERE shipment_class_id IN (
                SELECT id
                FROM sos.shipment_class
                WHERE use_truck_departure_times_for_sla = true
            )
        )
    );

    DELETE FROM sos.truck_departure__class
    WHERE shipment_class_id IN (
        SELECT id
        FROM sos.shipment_class
        WHERE use_truck_departure_times_for_sla = false
    );

COMMIT;