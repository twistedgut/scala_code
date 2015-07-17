-- DCA-52: Add comments describing the table and some of its columns

BEGIN;

COMMENT ON TABLE activemq_message IS 'Log ActiveMQ messages. Initially to be used for route_request and route_response messages';

COMMENT ON COLUMN activemq_message.entity_id IS 'most relevant ID from the message, e.g. container_id';
COMMENT ON COLUMN activemq_message.queue IS 'populated for outgoing messages, null for incoming';
COMMENT ON COLUMN activemq_message.content IS 'content column has a full text index for LIKE';

COMMIT;
