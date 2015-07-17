BEGIN TRANSACTION;

CREATE TABLE integration_container (
    id              SERIAL       NOT NULL PRIMARY KEY,
    container_id    VARCHAR(255) NOT NULL REFERENCES container(id) DEFERRABLE,
    prl_id          INTEGER      NOT NULL REFERENCES prl(id) DEFERRABLE,
    from_prl_id     INTEGER               REFERENCES prl(id) DEFERRABLE,
    is_complete     BOOLEAN      NOT NULL DEFAULT false,
    completed_at    TIMESTAMP WITH TIME ZONE,
    routed_at       TIMESTAMP WITH TIME ZONE,
    arrived_at      TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    modified_at     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE integration_container OWNER TO www;
GRANT ALL ON SEQUENCE integration_container_id_seq TO www;
CREATE INDEX ON integration_container(container_id);
CREATE INDEX ON integration_container(prl_id);
CREATE INDEX ON integration_container(from_prl_id);
CREATE INDEX ON integration_container(is_complete);
CREATE INDEX ON integration_container(completed_at);
CREATE INDEX ON integration_container(routed_at);
CREATE INDEX ON integration_container(arrived_at);

COMMENT ON TABLE integration_container IS
'A table to record details of containers that will be used during the
integration process. Initially this will only be used in DC2, for
integrating GOH and DCD allocations (and for putting GOH allocations
into totes to be sent to packing) but the schema supports integration
at any PRL.';
COMMENT ON COLUMN integration_container.prl_id IS
'The PRL at which the integration process is taking place.';
COMMENT ON COLUMN integration_container.from_prl_id IS
'If the container came from another PRL to be integrated, this records
which one. Will be null for containers that originated as an empty
container at integration.';
COMMENT ON COLUMN integration_container.is_complete IS
'Indicates whether the container is still at the integration point. Can
be used to exclude all completed containers from queries used during the
integration process, while keeping historical records for investigation if
items go missing later.';
COMMENT ON COLUMN integration_container.completed_at IS
'The time the operator confirms that the container is complete and can
be routed to packing.';
COMMENT ON COLUMN integration_container.routed_at IS
'For containers routed to integration from another PRL, this is the time
we sent the route_request message.';
COMMENT ON COLUMN integration_container.arrived_at IS
'For containers routed to integration from another PRL, this is the time
we received the route_response message. We are guaranteed to receive the
route_response messages in the same order that containers arrive at
integration, so we can use this value to provide a correctly-ordered list
of expected containers.';

CREATE TABLE integration_container_item (
    id                       SERIAL  NOT NULL PRIMARY KEY, -- TODO sequence
    integration_container_id INTEGER NOT NULL REFERENCES integration_container(id) DEFERRABLE,
    allocation_item_id       INTEGER NOT NULL REFERENCES allocation_item(id) DEFERRABLE,
    created_at               TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    modified_at              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE integration_container_item OWNER TO www;
GRANT ALL ON SEQUENCE integration_container_item_id_seq TO www;
CREATE INDEX ON integration_container_item(integration_container_id);
CREATE INDEX ON integration_container_item(allocation_item_id);
COMMENT ON TABLE integration_container_item IS
'Records allocation_items that have been scanned into containers at
integration.';

-- Automatically update the modified_at timestamp when a row is changed
CREATE OR REPLACE FUNCTION modified_at_func() RETURNS TRIGGER AS $$
    BEGIN
        NEW.modified_at := statement_timestamp();
        RETURN NEW;
    END;
$$
LANGUAGE 'plpgsql';
CREATE TRIGGER integration_container_modified_at_tr
    BEFORE UPDATE ON integration_container
    FOR EACH ROW EXECUTE PROCEDURE modified_at_func();

CREATE TRIGGER integration_container_item_modified_at_tr
    BEFORE UPDATE ON integration_container_item
    FOR EACH ROW EXECUTE PROCEDURE modified_at_func();

COMMIT;
