-- CANDO-373: New tables to support the Delivery/Collection information supplied by
--            Route Monkey so that it can be displayed on the Order View page

BEGIN WORK;

--
-- 'routing_schedule_type' table
--
CREATE TABLE routing_schedule_type (
    id          SERIAL NOT NULL PRIMARY KEY,
    name        CHARACTER VARYING(50) NOT NULL,
    UNIQUE(name)
);
ALTER TABLE routing_schedule_type OWNER TO postgres;
GRANT ALL ON TABLE routing_schedule_type TO postgres;
GRANT ALL ON TABLE routing_schedule_type TO www;

GRANT ALL ON SEQUENCE routing_schedule_type_id_seq TO postgres;
GRANT ALL ON SEQUENCE routing_schedule_type_id_seq TO www;

-- populate it
INSERT INTO routing_schedule_type (name) VALUES
    ('Delivery'),
    ('Collection')
;

--
-- 'routing_schedule_status' table
--
CREATE TABLE routing_schedule_status (
    id          SERIAL NOT NULL PRIMARY KEY,
    name        CHARACTER VARYING(100) NOT NULL,
    UNIQUE(name)
);
ALTER TABLE routing_schedule_status OWNER TO postgres;
GRANT ALL ON TABLE routing_schedule_status TO postgres;
GRANT ALL ON TABLE routing_schedule_status TO www;

GRANT ALL ON SEQUENCE routing_schedule_status_id_seq TO postgres;
GRANT ALL ON SEQUENCE routing_schedule_status_id_seq TO www;

-- populate it
INSERT INTO routing_schedule_status (name) VALUES
    ('Scheduled'),
    ('Shipment collected'),
    ('Shipment delivered'),
    ('Shipment undelivered'),
    ('Shipment uncollected'),
    ('Re-scheduled')
;

--
-- 'routing_schedule' table
--
CREATE TABLE routing_schedule (
    id                          SERIAL NOT NULL PRIMARY KEY,
    routing_schedule_type_id    INTEGER NOT NULL REFERENCES routing_schedule_type(id),
    routing_schedule_status_id  INTEGER NOT NULL REFERENCES routing_schedule_status(id),
    external_id                 CHARACTER VARYING(50),
    date_imported               TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    task_window_date            DATE,
    task_window                 CHARACTER VARYING(50),
    driver                      CHARACTER VARYING(100),
    run_number                  INTEGER,
    run_order_number            INTEGER,
    signatory                   CHARACTER VARYING(100),
    signature_time              TIMESTAMP WITH TIME ZONE,
    undelivered_notes           CHARACTER VARYING(1000)
);
ALTER TABLE routing_schedule OWNER TO postgres;
GRANT ALL ON TABLE routing_schedule TO postgres;
GRANT ALL ON TABLE routing_schedule TO www;

GRANT ALL ON SEQUENCE routing_schedule_id_seq TO postgres;
GRANT ALL ON SEQUENCE routing_schedule_id_seq TO www;


--
-- The following are link tables which will be used to link
-- the above 'routing_schedule' table to either a Shipment or RMA
--

--
-- 'link_routing_schedule__shipment'
--
CREATE TABLE link_routing_schedule__shipment (
    routing_schedule_id     INTEGER NOT NULL REFERENCES routing_schedule(id),
    shipment_id             INTEGER NOT NULL REFERENCES shipment(id),
    PRIMARY KEY( routing_schedule_id, shipment_id ),
    UNIQUE( routing_schedule_id )
);
ALTER TABLE link_routing_schedule__shipment OWNER TO postgres;
GRANT ALL ON TABLE link_routing_schedule__shipment TO postgres;
GRANT ALL ON TABLE link_routing_schedule__shipment TO www;

--
-- 'link_routing_schedule__shipment'
--
CREATE TABLE link_routing_schedule__return (
    routing_schedule_id     INTEGER NOT NULL REFERENCES routing_schedule(id),
    return_id               INTEGER NOT NULL REFERENCES return(id),
    PRIMARY KEY( routing_schedule_id, return_id ),
    UNIQUE( routing_schedule_id )
);
ALTER TABLE link_routing_schedule__return OWNER TO postgres;
GRANT ALL ON TABLE link_routing_schedule__return TO postgres;
GRANT ALL ON TABLE link_routing_schedule__return TO www;

COMMIT WORK;
