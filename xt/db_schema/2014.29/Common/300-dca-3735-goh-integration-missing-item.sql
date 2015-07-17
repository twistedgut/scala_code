BEGIN;

CREATE TABLE integration_container_item_status (
    id              INTEGER      NOT NULL PRIMARY KEY,
    status          TEXT NOT NULL,
    description     TEXT NOT NULL
);
ALTER TABLE integration_container_item_status OWNER TO www;
INSERT INTO integration_container_item_status (id, status, description) VALUES
    (1, 'Integrated', 'Item has been placed in container at integration'),
    (2, 'Picked', 'Item was picked into container then sent to integration'),
    (3, 'Missing', 'Item was marked as missing by operator at integration, and is conceptually now in the integration container rather than still in the PRL area - the associated shipment item will be marked as missing later, during the normal packing exception process');

ALTER TABLE integration_container_item
    ADD COLUMN status_id INTEGER NOT NULL REFERENCES integration_container_item_status(id) DEFERRABLE;
CREATE INDEX ON integration_container_item(status_id);

COMMIT;
