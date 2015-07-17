-- CANDO-2116: Adds Fraud Rule Tables in a new
--             Schema called 'fraud'

BEGIN WORK;

CREATE SCHEMA fraud;
GRANT ALL ON SCHEMA fraud TO postgres;
GRANT ALL ON SCHEMA fraud TO www;

-- Rule Status
CREATE TABLE fraud.rule_status (
    id          SERIAL NOT NULL PRIMARY KEY,
    status      CHARACTER VARYING(255) NOT NULL,
    UNIQUE (status)
);
ALTER TABLE fraud.rule_status OWNER TO postgres;
GRANT ALL ON TABLE fraud.rule_status TO www;
GRANT ALL ON SEQUENCE fraud.rule_status_id_seq TO www;


-- Change Log
CREATE TABLE fraud.change_log (
    id              SERIAL NOT NULL PRIMARY KEY,
    description     TEXT NOT NULL,
    operator_id     INTEGER REFERENCES public.operator(id),
    created         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE fraud.change_log OWNER TO postgres;
GRANT ALL ON TABLE fraud.change_log TO www;
GRANT ALL ON SEQUENCE fraud.change_log_id_seq TO www;


--
-- Rule Tables
--

--Archive
CREATE TABLE fraud.archived_rule (
    id                      SERIAL NOT NULL PRIMARY KEY,
    channel_id              INTEGER REFERENCES public.channel(id),
    rule_sequence           INTEGER NOT NULL,
    name                    CHARACTER VARYING(255) NOT NULL,
    start_date              TIMESTAMP WITH TIME ZONE,
    end_date                TIMESTAMP WITH TIME ZONE,
    enabled                 BOOLEAN NOT NULL DEFAULT TRUE,
    action_order_status_id  INTEGER NOT NULL REFERENCES public.order_status(id),
    metric_used             INTEGER NOT NULL DEFAULT 0,
    metric_decided          INTEGER NOT NULL DEFAULT 0,
    change_log_id           INTEGER NOT NULL REFERENCES fraud.change_log(id),
    created                 TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    created_by_operator_id  INTEGER NOT NULL REFERENCES public.operator(id),
    expired                 TIMESTAMP WITH TIME ZONE,
    expired_by_operator_id  INTEGER REFERENCES public.operator(id)
);
CREATE UNIQUE INDEX idx_fraud_archived_rule_channel_id_name_change_log_id ON fraud.archived_rule( COALESCE(channel_id, 0::integer), LOWER(name::text), change_log_id );

ALTER TABLE fraud.archived_rule OWNER TO postgres;
GRANT ALL ON TABLE fraud.archived_rule TO www;
GRANT ALL ON SEQUENCE fraud.archived_rule_id_seq TO www;

-- Live
CREATE TABLE fraud.live_rule (
    id                      SERIAL NOT NULL PRIMARY KEY,
    channel_id              INTEGER REFERENCES public.channel(id),
    rule_sequence           INTEGER NOT NULL UNIQUE,
    name                    CHARACTER VARYING(255) NOT NULL,
    start_date              TIMESTAMP WITH TIME ZONE,
    end_date                TIMESTAMP WITH TIME ZONE,
    enabled                 BOOLEAN NOT NULL DEFAULT TRUE,
    action_order_status_id  INTEGER NOT NULL REFERENCES public.order_status(id),
    metric_used             INTEGER NOT NULL DEFAULT 0,
    metric_decided          INTEGER NOT NULL DEFAULT 0,
    archived_rule_id        INTEGER NOT NULL REFERENCES fraud.archived_rule(id)
);
CREATE UNIQUE INDEX idx_fraud_live_rule_channel_id_name ON fraud.live_rule( COALESCE(channel_id, 0::integer), LOWER(name::text) );

ALTER TABLE fraud.live_rule OWNER TO postgres;
GRANT ALL ON TABLE fraud.live_rule TO www;
GRANT ALL ON SEQUENCE fraud.live_rule_id_seq TO www;

-- Staging
CREATE TABLE fraud.staging_rule (
    id                      SERIAL NOT NULL PRIMARY KEY,
    channel_id              INTEGER REFERENCES public.channel(id),
    rule_sequence           INTEGER NOT NULL UNIQUE,
    name                    CHARACTER VARYING(255) NOT NULL,
    start_date              TIMESTAMP WITH TIME ZONE,
    end_date                TIMESTAMP WITH TIME ZONE,
    enabled                 BOOLEAN NOT NULL DEFAULT TRUE,
    rule_status_id          INTEGER NOT NULL REFERENCES fraud.rule_status(id),
    action_order_status_id  INTEGER NOT NULL REFERENCES public.order_status(id),
    live_rule_id            INTEGER REFERENCES fraud.live_rule(id),
    metric_used             INTEGER NOT NULL DEFAULT 0,
    metric_decided          INTEGER NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX idx_fraud_staging_rule_channel_id_name ON fraud.staging_rule( COALESCE(channel_id, 0::integer), LOWER(name::text) );

ALTER TABLE fraud.staging_rule OWNER TO postgres;
GRANT ALL ON TABLE fraud.staging_rule TO www;
GRANT ALL ON SEQUENCE fraud.staging_rule_id_seq TO www;


-- Return Value Types
CREATE TABLE fraud.return_value_type (
    id              SERIAL NOT NULL PRIMARY KEY,
    type            CHARACTER VARYING(255) NOT NULL UNIQUE,
    regex           CHARACTER VARYING(255) NOT NULL
);

ALTER TABLE fraud.return_value_type OWNER TO postgres;
GRANT ALL ON TABLE fraud.return_value_type TO www;
GRANT ALL ON SEQUENCE fraud.return_value_type_id_seq TO www;


--
-- Method Table
--
CREATE TABLE fraud.method (
    id                          SERIAL NOT NULL PRIMARY KEY,
    description                 CHARACTER VARYING(255) NOT NULL,
    object_to_use               CHARACTER VARYING(255) NOT NULL,
    method_to_call              CHARACTER VARYING(255) NOT NULL,
    method_parameters           CHARACTER VARYING(255),
    return_value_type_id        INTEGER NOT NULL REFERENCES fraud.return_value_type(id),
    rule_action_helper_method   CHARACTER VARYING(255),
    processing_cost             SMALLINT NOT NULL DEFAULT 100
);
CREATE UNIQUE INDEX idx_fraud_method_name ON fraud.method( LOWER(description::text) );

ALTER TABLE fraud.method OWNER TO postgres;
GRANT ALL ON TABLE fraud.method TO www;
GRANT ALL ON SEQUENCE fraud.method_id_seq TO www;


-- Conditional Operator
CREATE TABLE fraud.conditional_operator (
    id                          SERIAL NOT NULL PRIMARY KEY,
    description                 CHARACTER VARYING(255) NOT NULL,
    symbol                      CHARACTER VARYING(255) NOT NULL,
    perl_operator               CHARACTER VARYING(255)
);
CREATE UNIQUE INDEX idx_conditional_operator_unique ON fraud.conditional_operator( description, symbol, COALESCE(perl_operator, ''::text) );

ALTER TABLE fraud.conditional_operator OWNER TO postgres;
GRANT ALL ON TABLE fraud.conditional_operator TO www;
GRANT ALL ON SEQUENCE fraud.conditional_operator_id_seq TO www;


-- Link Return Value Type to Conditional Operator Table
CREATE TABLE fraud.link_return_value_type__conditional_operator (
    return_value_type_id        INTEGER NOT NULL REFERENCES fraud.return_value_type(id),
    conditional_operator_id     INTEGER NOT NULL REFERENCES fraud.conditional_operator(id),
    PRIMARY KEY (return_value_type_id,conditional_operator_id)
);

ALTER TABLE fraud.link_return_value_type__conditional_operator OWNER TO postgres;
GRANT ALL ON TABLE fraud.link_return_value_type__conditional_operator TO www;


--
-- Condition Tables
--

CREATE TABLE fraud.live_condition (
    id                          SERIAL NOT NULL PRIMARY KEY,
    rule_id                     INTEGER REFERENCES fraud.live_rule(id) NOT NULL,
    method_id                   INTEGER REFERENCES fraud.method(id) NOT NULL,
    conditional_operator_id     INTEGER REFERENCES fraud.conditional_operator(id) NOT NULL,
    value                       CHARACTER VARYING(255) NOT NULL,
    enabled                     BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE fraud.live_condition OWNER TO postgres;
GRANT ALL ON TABLE fraud.live_condition TO www;
GRANT ALL ON SEQUENCE fraud.live_condition_id_seq TO www;

CREATE TABLE fraud.staging_condition (
    id                          SERIAL NOT NULL PRIMARY KEY,
    rule_id                     INTEGER REFERENCES fraud.staging_rule(id) NOT NULL,
    method_id                   INTEGER REFERENCES fraud.method(id) NOT NULL,
    conditional_operator_id     INTEGER REFERENCES fraud.conditional_operator(id) NOT NULL,
    value                       CHARACTER VARYING(255) NOT NULL,
    enabled                     BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE fraud.staging_condition OWNER TO postgres;
GRANT ALL ON TABLE fraud.staging_condition TO www;
GRANT ALL ON SEQUENCE fraud.staging_condition_id_seq TO www;

CREATE TABLE fraud.archived_condition (
    id                          SERIAL NOT NULL PRIMARY KEY,
    rule_id                     INTEGER REFERENCES fraud.archived_rule(id) NOT NULL,
    method_id                   INTEGER REFERENCES fraud.method(id) NOT NULL,
    conditional_operator_id     INTEGER REFERENCES fraud.conditional_operator(id) NOT NULL,
    value                       CHARACTER VARYING(255) NOT NULL,
    enabled                     BOOLEAN NOT NULL DEFAULT TRUE,
    change_log_id               INTEGER NOT NULL REFERENCES fraud.change_log(id),
    created                     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    created_by_operator_id      INTEGER NOT NULL REFERENCES public.operator(id),
    expired                     TIMESTAMP WITH TIME ZONE,
    expired_by_operator_id      INTEGER REFERENCES public.operator(id)
);

ALTER TABLE fraud.archived_condition OWNER TO postgres;
GRANT ALL ON TABLE fraud.archived_condition TO www;
GRANT ALL ON SEQUENCE fraud.archived_condition_id_seq TO www;


--
-- Orders Rule Outcome table
--

CREATE TABLE fraud.rule_outcome_status (
    id      SERIAL NOT NULL PRIMARY KEY,
    status  CHARACTER VARYING (255) NOT NULL UNIQUE
);
ALTER TABLE fraud.rule_outcome_status OWNER TO postgres;
GRANT ALL ON TABLE fraud.rule_outcome_status TO www;
GRANT ALL ON SEQUENCE fraud.rule_outcome_status_id_seq TO www;

CREATE TABLE fraud.orders_rule_outcome (
    id                          SERIAL NOT NULL PRIMARY KEY,
    orders_id                   INTEGER NOT NULL REFERENCES public.orders(id) UNIQUE,
    archived_rule_id            INTEGER REFERENCES fraud.archived_rule(id),
    finance_flag_ids            CHARACTER VARYING (255),
    textualisation              TEXT NOT NULL,
    rule_outcome_status_id      INTEGER NOT NULL REFERENCES fraud.rule_outcome_status(id),
    created                     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

ALTER TABLE fraud.orders_rule_outcome OWNER TO postgres;
GRANT ALL ON TABLE fraud.orders_rule_outcome TO www;
GRANT ALL ON SEQUENCE fraud.orders_rule_outcome_id_seq TO www;

--
-- Fraud Rules Engine Switch Log
--
CREATE TABLE fraud.log_rule_engine_switch_position (
    id                      SERIAL NOT NULL PRIMARY KEY,
    channel_id              INTEGER NOT NULL REFERENCES public.channel(id),
    position                CHARACTER VARYING (255) NOT NULL,
    operator_id             INTEGER NOT NULL REFERENCES public.operator(id),
    date                    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);
ALTER TABLE fraud.log_rule_engine_switch_position OWNER TO postgres;
GRANT ALL ON TABLE fraud.log_rule_engine_switch_position TO www;
GRANT ALL ON SEQUENCE fraud.log_rule_engine_switch_position_id_seq TO www;

--
-- Populate Lookup Tables
--

INSERT INTO fraud.rule_status (status) VALUES
    ('Unchanged'),
    ('Changed'),
    ('New')
;

INSERT INTO fraud.rule_outcome_status (status) VALUES
    ('Applied to Order'),
    ('Parallel Expected Outcome'),
    ('Parallel Unexpected Outcome')
;

INSERT INTO fraud.return_value_type (type, regex) VALUES
    ('boolean', E'^(true|t|y|1|false|f|n|0)$'),
    ('string', E'^[\\w. -]{0,255}$'),
    ('integer', E'^[+-]?\\d+$'),
    ('decimal', E'^[+-]?(?:\\d+(?:\.\\d*)?|\.\\d+)$'),
    ('dbid', E'^\\d+$')
;

INSERT INTO fraud.conditional_operator (description,symbol,perl_operator) VALUES
    ('Equal To', '=', '=='),
    ('Not Equal To', '!=', '!='),
    ('Greater Than', '>', '>'),
    ('Less Than', '<', '<'),
    ('Greater Than or Equal To', '>=', '>='),
    ('Less Than or Equal To', '<=', '<='),
    ('Is','Is',NULL),
    ('Equal To', '=', 'eq'),
    ('Not Equal To', '!=', 'ne')
;

-- Link to INTEGER & DECIMAL to Conditional Operators
INSERT INTO fraud.link_return_value_type__conditional_operator (return_value_type_id, conditional_operator_id)
SELECT  rvt.id, co.id
FROM    fraud.return_value_type rvt,
        fraud.conditional_operator co
WHERE   rvt.type IN ('integer','decimal')
AND     co.perl_operator IN ( '==', '!=', '>', '<', '>=', '<=' )
ORDER BY rvt.id,co.id
;

-- Link to STRING to Conditional Operators
INSERT INTO fraud.link_return_value_type__conditional_operator (return_value_type_id, conditional_operator_id)
SELECT  rvt.id, co.id
FROM    fraud.return_value_type rvt,
        fraud.conditional_operator co
WHERE   rvt.type IN ('string')
AND     co.perl_operator IN ( 'eq', 'ne' )
ORDER BY rvt.id,co.id
;

-- Link to BOOLEAN to Conditional Operators
INSERT INTO fraud.link_return_value_type__conditional_operator (return_value_type_id, conditional_operator_id)
SELECT  rvt.id, co.id
FROM    fraud.return_value_type rvt,
        fraud.conditional_operator co
WHERE   rvt.type IN ('boolean')
AND     co.description = 'Is'
ORDER BY rvt.id,co.id
;

-- Link to ID to Conditional Operators
INSERT INTO fraud.link_return_value_type__conditional_operator (return_value_type_id, conditional_operator_id)
SELECT  rvt.id, co.id
FROM    fraud.return_value_type rvt,
        fraud.conditional_operator co
WHERE   rvt.type IN ('dbid')
AND     co.perl_operator IN ( '==', '!=' )
ORDER BY rvt.id,co.id
;

COMMIT WORK;
