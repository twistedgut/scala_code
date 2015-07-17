--CANDO-1324: Add Customer segment with Customer List for Marketing Promotions


BEGIN WORK;

--marketing_customer_segment

CREATE TABLE marketing_customer_segment (
    id                              SERIAL NOT NULL PRIMARY KEY,
    name                            VARCHAR(255) NOT NULL,
    channel_id                      INTEGER NOT NULL REFERENCES public.channel(id),
    enabled                         BOOLEAN DEFAULT TRUE NOT NULL,
    created_date                    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operator_id                     INTEGER REFERENCES public.operator(id) NOT NULL,
    job_queue_flag                  BOOLEAN,
    date_of_last_jq                 TIMESTAMP WITH TIME ZONE,
    UNIQUE ( name, channel_id)
);

ALTER TABLE marketing_customer_segment OWNER TO postgres;
GRANT ALL ON TABLE marketing_customer_segment TO postgres;
GRANT ALL ON TABLE marketing_customer_segment TO www;

GRANT ALL ON SEQUENCE marketing_customer_segment_id_seq TO postgres;
GRANT ALL ON SEQUENCE marketing_customer_segment_id_seq TO www;

--marketing_customer_segment_log

CREATE TABLE marketing_customer_segment_log (
    id                              SERIAL NOT NULL PRIMARY KEY,
    customer_segment_id            INTEGER NOT NULL REFERENCES public.marketing_customer_segment(id),
    enabled_state                   BOOLEAN,
    date                            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operator_id                     INTEGER NOT NULL REFERENCES public.operator(id)
);
ALTER TABLE marketing_customer_segment_log OWNER TO postgres;
GRANT ALL ON TABLE marketing_customer_segment_log TO postgres;
GRANT ALL ON TABLE marketing_customer_segment_log TO www;

GRANT ALL ON SEQUENCE marketing_customer_segment_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE marketing_customer_segment_log_id_seq TO www;

--link_marketing_promotion__customer_segment

CREATE TABLE link_marketing_promotion__customer_segment (
    marketing_promotion_id          INTEGER NOT NULL REFERENCES marketing_promotion(id),
    customer_segment_id            INTEGER NOT NULL REFERENCES marketing_customer_segment(id),
    UNIQUE (marketing_promotion_id, customer_segment_id)
);

ALTER TABLE  link_marketing_promotion__customer_segment OWNER    TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__customer_segment    TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__customer_segment    TO www;

CREATE INDEX link_marketing_promotion__customer_segment__marketing_promotion_idx ON link_marketing_promotion__customer_segment(marketing_promotion_id);
CREATE INDEX link_marketing_promotion__customer_segment__customer_segment_idx ON link_marketing_promotion__customer_segment(customer_segment_id);


--link_marketing_customer_segment__customer

CREATE TABLE link_marketing_customer_segment__customer(
    customer_segment_id            INTEGER NOT NULL REFERENCES marketing_customer_segment(id),
    customer_id                    INTEGER NOT NULL REFERENCES customer(id),
    UNIQUE (customer_segment_id, customer_id)

);

ALTER TABLE link_marketing_customer_segment__customer OWNER TO postgres;
GRANT ALL ON TABLE  link_marketing_customer_segment__customer   TO postgres;
GRANT ALL ON TABLE  link_marketing_customer_segment__customer   TO www;

CREATE INDEX link_marketing_customer_segment__customer__marketing_customer_idx on link_marketing_customer_segment__customer(customer_segment_id);
CREATE INDEX link_marketing_customer_segment__customer__customer_idx on link_marketing_customer_segment__customer(customer_id);

COMMIT WORK;
