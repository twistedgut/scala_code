BEGIN;

    -- Some shipment classes ignore ALL other processing times except those for this
    -- shipment clas itself. This is indicated by the following flag
    ALTER TABLE sos.shipment_class ADD COLUMN does_ignore_other_processing_times BOOLEAN NOT NULL DEFAULT FALSE;

    UPDATE sos.shipment_class SET does_ignore_other_processing_times = TRUE WHERE use_truck_departure_times_for_sla = FALSE;

COMMIT;