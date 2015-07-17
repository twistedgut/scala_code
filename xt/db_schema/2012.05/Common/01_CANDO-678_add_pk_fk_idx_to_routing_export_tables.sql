-- CANDO-678: Add FK Constraint to the 'channel_id' column
--            of the 'routing_export' table and other
--            improvements to related tables

BEGIN WORK;

ALTER TABLE routing_export
    ALTER COLUMN channel_id SET NOT NULL,
    ADD CONSTRAINT routing_export_channel_id_fkey FOREIGN KEY (channel_id) REFERENCES channel(id)
;

-- add a Primary Key to 'link_routing_export__shipment'
ALTER TABLE link_routing_export__shipment
    ADD PRIMARY KEY (routing_export_id, shipment_id)
;

-- add Indexes to 'link_routing_export__return'
CREATE INDEX link_routing_export__return_routing_export_id_fkey ON link_routing_export__return(routing_export_id);
CREATE INDEX link_routing_export__return_return_id_fkey ON link_routing_export__return(return_id);

COMMIT WORK;
