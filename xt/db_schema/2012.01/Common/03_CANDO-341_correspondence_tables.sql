-- CANDO-341: Add various Correspondence Tables

BEGIN WORK;

--
-- Create new Tables
--

-- correspondence_method
CREATE TABLE correspondence_method (
    id              SERIAL NOT NULL PRIMARY KEY,
    method          CHARACTER VARYING(30) NOT NULL UNIQUE,
    description     CHARACTER VARYING(255) NOT NULL,
    can_opt_out     BOOLEAN NOT NULL,
    enabled         BOOLEAN NOT NULL DEFAULT TRUE
);
ALTER TABLE correspondence_method OWNER TO postgres;
GRANT ALL ON TABLE correspondence_method TO postgres;
GRANT ALL ON TABLE correspondence_method TO www;

GRANT ALL ON SEQUENCE correspondence_method_id_seq TO postgres;
GRANT ALL ON SEQUENCE correspondence_method_id_seq TO www;

-- correspondence_subject
CREATE TABLE correspondence_subject (
    id              SERIAL NOT NULL PRIMARY KEY,
    subject         CHARACTER VARYING(255) NOT NULL,
    description     CHARACTER VARYING(255) NOT NULL,
    enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    channel_id      INTEGER NOT NULL REFERENCES channel(id),
    UNIQUE(subject,channel_id)
);
ALTER TABLE correspondence_subject OWNER TO postgres;
GRANT ALL ON TABLE correspondence_subject TO postgres;
GRANT ALL ON TABLE correspondence_subject TO www;

GRANT ALL ON SEQUENCE correspondence_subject_id_seq TO postgres;
GRANT ALL ON SEQUENCE correspondence_subject_id_seq TO www;

-- correspondence_subject_method
CREATE TABLE correspondence_subject_method (
    id                              SERIAL NOT NULL PRIMARY KEY,
    correspondence_subject_id       INTEGER NOT NULL REFERENCES correspondence_subject(id),
    correspondence_method_id        INTEGER NOT NULL REFERENCES correspondence_method(id),
    can_opt_out                     BOOLEAN NOT NULL,
    default_can_use                 BOOLEAN NOT NULL,
    enabled                         BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(correspondence_method_id,correspondence_subject_id)
);
ALTER TABLE correspondence_subject_method OWNER TO postgres;
GRANT ALL ON TABLE correspondence_subject_method TO postgres;
GRANT ALL ON TABLE correspondence_subject_method TO www;

GRANT ALL ON SEQUENCE correspondence_subject_method_id_seq TO postgres;
GRANT ALL ON SEQUENCE correspondence_subject_method_id_seq TO www;

-- customer_csm_preference
CREATE TABLE customer_csm_preference (
    id              SERIAL NOT NULL PRIMARY KEY,
    customer_id     INTEGER NOT NULL REFERENCES customer(id),
    csm_id          INTEGER NOT NULL REFERENCES correspondence_subject_method(id),
    can_use         BOOLEAN NOT NULL,
    UNIQUE(customer_id,csm_id)
);
CREATE INDEX customer_csm_preference_customer_id_idx ON customer_csm_preference(customer_id);
CREATE INDEX customer_csm_preference_csm_id_idx ON customer_csm_preference(csm_id);

ALTER TABLE customer_csm_preference OWNER TO postgres;
GRANT ALL ON TABLE customer_csm_preference TO postgres;
GRANT ALL ON TABLE customer_csm_preference TO www;

GRANT ALL ON SEQUENCE customer_csm_preference_id_seq TO postgres;
GRANT ALL ON SEQUENCE customer_csm_preference_id_seq TO www;

-- orders_csm_preference
CREATE TABLE orders_csm_preference (
    id              SERIAL NOT NULL PRIMARY KEY,
    orders_id       INTEGER NOT NULL REFERENCES orders(id),
    csm_id          INTEGER NOT NULL REFERENCES correspondence_subject_method(id),
    can_use         BOOLEAN NOT NULL,
    UNIQUE(orders_id,csm_id)
);
CREATE INDEX orders_csm_preference_customer_id_idx ON orders_csm_preference(orders_id);
CREATE INDEX orders_csm_preference_csm_id_idx ON orders_csm_preference(csm_id);

ALTER TABLE orders_csm_preference OWNER TO postgres;
GRANT ALL ON TABLE orders_csm_preference TO postgres;
GRANT ALL ON TABLE orders_csm_preference TO www;

GRANT ALL ON SEQUENCE orders_csm_preference_id_seq TO postgres;
GRANT ALL ON SEQUENCE orders_csm_preference_id_seq TO www;

-- customer_correspondence_method_preference
CREATE TABLE customer_correspondence_method_preference (
    id                          SERIAL NOT NULL PRIMARY KEY,
    customer_id                 INTEGER NOT NULL REFERENCES customer(id),
    correspondence_method_id    INTEGER NOT NULL REFERENCES correspondence_method(id),
    can_use                     BOOLEAN NOT NULL,
    UNIQUE(customer_id,correspondence_method_id)
);
CREATE INDEX customer_corr_meth_pref_customer_id_idx ON customer_correspondence_method_preference(customer_id);
CREATE INDEX customer_corr_meth_pref_corr_meth_id_idx ON customer_correspondence_method_preference(correspondence_method_id);

ALTER TABLE customer_correspondence_method_preference OWNER TO postgres;
GRANT ALL ON TABLE customer_correspondence_method_preference TO postgres;
GRANT ALL ON TABLE customer_correspondence_method_preference TO www;

GRANT ALL ON SEQUENCE customer_correspondence_method_preference_id_seq TO postgres;
GRANT ALL ON SEQUENCE customer_correspondence_method_preference_id_seq TO www;

-- Alter 'customer' table
ALTER TABLE customer
    ADD COLUMN correspondence_default_preference BOOLEAN
;


--
-- Populate Some of the Tables
--

-- 'correspondence_method'
INSERT INTO correspondence_method (method,description,can_opt_out) VALUES
( 'SMS', 'SMS', TRUE ),
( 'Email', 'Email', TRUE ),
( 'Phone', 'Phone', TRUE ),
( 'Document', 'Document', FALSE ),
( 'Label', 'Label', FALSE )
;

-- 'correspondence_subject'
INSERT INTO correspondence_subject (subject,description,channel_id)
SELECT  'Premier Delivery',
        'Premier Delivery/Collection Notification',
        ch.id
FROM    channel ch
        JOIN business b ON b.id = ch.business_id
                        AND b.config_section IN ('NAP','MRP','JC')
ORDER BY ch.id
;

-- 'correspondence_subject_method'
INSERT INTO correspondence_subject_method (correspondence_subject_id,correspondence_method_id,can_opt_out,default_can_use)
SELECT  cs.id,
        cm.id,
        cm.can_opt_out,
        CASE cm.method
            WHEN 'Phone' THEN FALSE
            ELSE TRUE
        END
FROM    correspondence_method cm,
        correspondence_subject cs
WHERE   cm.method IN ('SMS','Email','Phone')
AND     cs.subject = 'Premier Delivery'
ORDER BY cs.id,cm.id
;


COMMIT WORK;
