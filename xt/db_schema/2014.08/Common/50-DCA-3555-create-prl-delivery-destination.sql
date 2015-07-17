BEGIN;

CREATE TABLE prl_delivery_destination (
    id INTEGER NOT NULL primary key,
    prl_id INTEGER NOT NULL REFERENCES prl(id) DEFERRABLE,
    name TEXT NOT NULL,
    message_name TEXT NOT NULL,
    description TEXT NOT NULL
);

COMMENT ON TABLE prl_delivery_destination IS
'For PRLs that require allocations to go through a prepare+deliver process
(e.g. GOH PRL in DC2), we can include a destination in the prepare message
which specifies where we want the allocation to be delivered to. This table
contains the valid destinations for a PRL, and can be linked to from the
allocation table to record what was sent in the PRL::Prepare message.';

COMMENT ON COLUMN prl_delivery_destination.name IS
'This is the identifier we use for constants in code.';

COMMENT ON COLUMN prl_delivery_destination.message_name IS
'This is the identifier we use in the destination field of the PRL::Prepare
message.';

ALTER TABLE prl_delivery_destination OWNER TO www;

ALTER TABLE allocation ADD COLUMN prl_delivery_destination_id INTEGER
    REFERENCES prl_delivery_destination(id) DEFERRABLE;
CREATE INDEX idx_allocation_prl_delivery_destination ON allocation(prl_delivery_destination_id);

COMMIT;
