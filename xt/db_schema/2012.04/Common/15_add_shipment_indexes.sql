BEGIN;

CREATE INDEX idx_shipment_nominated_dispatch_time
    ON shipment(nominated_dispatch_time);


COMMIT;
