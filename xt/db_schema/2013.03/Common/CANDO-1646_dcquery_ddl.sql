-- Story:       CANDO-1646
-- Description: Create a table to store remote DC query references

BEGIN WORK;

CREATE TABLE remote_dc_query (
    id              varchar(255) PRIMARY KEY,
    query_type      varchar(255) NOT NULL,
    orders_id       integer NOT NULL REFERENCES orders(id),
    date_created    timestamp WITH TIME ZONE NOT NULL DEFAULT now(),
    processed       boolean NOT NULL default false
);

ALTER TABLE remote_dc_query OWNER TO postgres;
GRANT ALL ON TABLE remote_dc_query TO www;

INSERT INTO flag values (default,'Released via Remote DC Query',2);
INSERT INTO flag values (default,'Remote DC Query Potential Fraud',2);

COMMIT;
