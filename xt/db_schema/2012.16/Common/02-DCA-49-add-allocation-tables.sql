
-- DCA-49 - Implement Allocation Manager in XT
--  \-> DCA-1087 - Setup database wrappers
--
-- Essentially, this is the introduction of the allocation and
-- allocation_item tables in XT. We introduce it for all DCs (as per best
-- practice) although we'll only be using the tables in DCs which support the
-- PRL architecture
--

BEGIN;

CREATE TABLE allocation (
    id          SERIAL NOT NULL PRIMARY KEY,
    shipment_id INT NOT NULL REFERENCES shipment (id),
    prl         VARCHAR(16) NOT NULL,
    is_open     BOOLEAN DEFAULT true
);

GRANT ALL ON TABLE allocation TO postgres;
GRANT ALL ON TABLE allocation TO www;
GRANT ALL ON SEQUENCE allocation_id_seq TO postgres;
GRANT ALL ON SEQUENCE allocation_id_seq TO www;

CREATE TABLE allocation_item_status (
    id           SERIAL NOT NULL PRIMARY KEY,
    status       VARCHAR(255) UNIQUE,
    is_end_state BOOLEAN NOT NULL,
    description  TEXT NOT NULL
);
GRANT ALL ON TABLE allocation_item_status TO postgres;
GRANT ALL ON TABLE allocation_item_status TO www;
GRANT ALL ON SEQUENCE allocation_item_status_id_seq TO postgres;
GRANT ALL ON SEQUENCE allocation_item_status_id_seq TO www;
INSERT INTO allocation_item_status (status, is_end_state, description) VALUES
    ( 'requested', false, 'PRL has been asked to allocate item, no response yet' ),
    ( 'allocated', false, 'PRL has successfully allocated the item' ),
    ( 'short',     true,  'PRL can not allocate the item' ),
    ( 'cancelled', true,  'Item has been cancelled in XT' ),
    ( 'picking',   false, 'PRL has been asked to pick formerly allocated item' ),
    ( 'picked',    true,  'PRL has sent us a pick_complete for the item' );

CREATE TABLE allocation_item (
    id               SERIAL NOT NULL PRIMARY KEY,
    status_id        INT NOT NULL REFERENCES allocation_item_status (id),
    shipment_item_id INT NOT NULL REFERENCES shipment_item (id),
    allocation_id    INT NOT NULL REFERENCES allocation (id)
);
GRANT ALL ON TABLE allocation_item TO postgres;
GRANT ALL ON TABLE allocation_item TO www;
GRANT ALL ON SEQUENCE allocation_item_id_seq TO postgres;
GRANT ALL ON SEQUENCE allocation_item_id_seq TO www;

COMMIT;

