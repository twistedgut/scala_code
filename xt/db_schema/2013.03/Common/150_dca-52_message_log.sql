-- DCA-52: Create table to log ActiveMQ messages
--          Initially to be used for route_request and route_response messages

BEGIN;

CREATE SEQUENCE activemq_message_id_seq
    INCREMENT BY 1 NO MAXVALUE NO MINVALUE START WITH 1 CACHE 1;

CREATE TABLE activemq_message (
    id INTEGER PRIMARY KEY DEFAULT NEXTVAL('activemq_message_id_seq'),
    message_type VARCHAR(255) NOT NULL,
    entity_id VARCHAR(255) NULL, -- most relevant ID from the message, e.g. container_id
    entity_type VARCHAR(255) NULL, -- text for now, could change to lookup later
    queue VARCHAR(50) NULL, -- will be null for incoming messages
    created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    content TEXT NOT NULL
);

ALTER SEQUENCE activemq_message_id_seq OWNER TO postgres;
GRANT ALL ON SEQUENCE activemq_message_id_seq TO postgres;
GRANT ALL ON SEQUENCE activemq_message_id_seq TO www;

ALTER TABLE activemq_message OWNER TO postgres;
GRANT ALL ON TABLE activemq_message TO postgres;
GRANT ALL ON TABLE activemq_message TO www;

CREATE INDEX idx_activemq_message__entity_id ON activemq_message (entity_id);
CREATE INDEX idx_activemq_message__entity_type ON activemq_message (entity_type);
CREATE INDEX idx_activemq_message__queue ON activemq_message (queue);
CREATE INDEX idx_activemq_message__created ON activemq_message (created);
CREATE INDEX idx_activemq_message__content ON activemq_message (content text_pattern_ops); -- full text index for 'LIKE'

COMMIT;
