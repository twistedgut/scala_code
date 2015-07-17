-- CANDO-880: Creating tables for Marketing campaign - "In The Box"

BEGIN WORK;


-- marketing_promotion table
CREATE TABLE marketing_promotion (
    id                              SERIAL NOT NULL PRIMARY KEY,
    title                           VARCHAR(255) NOT NULL,
    channel_id                      INTEGER NOT NULL REFERENCES public.channel(id),
    description                     TEXT,
    start_date                      TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date                        TIMESTAMP WITH TIME ZONE NOT NULL,
    enabled                         BOOLEAN DEFAULT TRUE NOT NULL,
    is_sent_once                    BOOLEAN NOT NULL DEFAULT TRUE,
    message                         TEXT NOT NULL,
    created_date                    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operator_id                     INTEGER REFERENCES public.operator(id) NOT NULL
);

ALTER TABLE marketing_promotion OWNER TO postgres;
GRANT ALL ON TABLE marketing_promotion TO postgres;
GRANT ALL ON TABLE marketing_promotion TO www;

GRANT ALL ON SEQUENCE marketing_promotion_id_seq TO postgres;
GRANT ALL ON SEQUENCE marketing_promotion_id_seq TO www;


-- marketing_promotion_log table
CREATE TABLE marketing_promotion_log (
    id                              SERIAL NOT NULL PRIMARY KEY,
    marketing_promotion_id          INTEGER NOT NULL REFERENCES public.marketing_promotion(id),
    enabled_state                   BOOLEAN,
    date                            TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    operator_id                     INTEGER NOT NULL REFERENCES public.operator(id)
);

ALTER TABLE marketing_promotion_log OWNER TO postgres;
GRANT ALL ON TABLE marketing_promotion_log TO postgres;
GRANT ALL ON TABLE marketing_promotion_log TO www;

GRANT ALL ON SEQUENCE marketing_promotion_log_id_seq TO postgres;
GRANT ALL ON SEQUENCE marketing_promotion_log_id_seq TO www;

-- link_orders__marketing_promotion table
CREATE TABLE link_orders__marketing_promotion (
    orders_id                       INTEGER NOT NULL REFERENCES orders(id),
    marketing_promotion_id          INTEGER NOT NULL REFERENCES marketing_promotion(id),
    UNIQUE (orders_id,marketing_promotion_id)
);

ALTER TABLE link_orders__marketing_promotion OWNER     TO postgres;
GRANT ALL ON TABLE link_orders__marketing_promotion    TO postgres;
GRANT ALL ON TABLE link_orders__marketing_promotion    TO www;

CREATE INDEX link_orders__marketing_promotion__orders_idx    ON link_orders__marketing_promotion(orders_id);
CREATE INDEX link_orders__marketing_promotion__marketing_promotion_idx ON link_orders__marketing_promotion(marketing_promotion_id);

COMMIT WORK;
