-- CANDO-1844: Add New Link Tables

BEGIN WORK;

--
-- Create Title Table using the term Gender Proxy
-- so that it wont be used by any other part of
-- xTracker has a general Title Lookup, if this
-- is required then it should be done using Seaview
--
CREATE TABLE marketing_gender_proxy (
    id          SERIAL NOT NULL PRIMARY KEY,
    title       CHARACTER VARYING (255) NOT NULL UNIQUE
);
ALTER TABLE marketing_gender_proxy OWNER TO postgres;
GRANT ALL ON TABLE marketing_gender_proxy TO www;
GRANT ALL ON SEQUENCE marketing_gender_proxy_id_seq TO www;

-- Populate it
INSERT INTO marketing_gender_proxy (title) VALUES
('Dr'),
('Lord'),
('Miss'),
('Mr'),
('Mrs'),
('Ms'),
('Prof'),
('Rev'),
('Sir')
;


--
-- Create Link Tables
--

CREATE TABLE link_marketing_promotion__gender_proxy (
    marketing_promotion_id      INTEGER NOT NULL REFERENCES marketing_promotion(id),
    gender_proxy_id             INTEGER NOT NULL REFERENCES marketing_gender_proxy(id),
    include                     BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (marketing_promotion_id,gender_proxy_id)
);
ALTER TABLE link_marketing_promotion__gender_proxy OWNER TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__gender_proxy TO www;


CREATE TABLE link_marketing_promotion__country (
    marketing_promotion_id      INTEGER NOT NULL REFERENCES marketing_promotion(id),
    country_id                  INTEGER NOT NULL REFERENCES country(id),
    include                     BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (marketing_promotion_id,country_id)
);
ALTER TABLE link_marketing_promotion__country OWNER TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__country TO www;


CREATE TABLE link_marketing_promotion__language (
    marketing_promotion_id      INTEGER NOT NULL REFERENCES marketing_promotion(id),
    language_id                 INTEGER NOT NULL REFERENCES language(id),
    include                     BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (marketing_promotion_id,language_id)
);
ALTER TABLE link_marketing_promotion__language OWNER TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__language TO www;


CREATE TABLE link_marketing_promotion__product_type (
    marketing_promotion_id      INTEGER NOT NULL REFERENCES marketing_promotion(id),
    product_type_id             INTEGER NOT NULL REFERENCES product_type(id),
    include                     BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (marketing_promotion_id,product_type_id)
);
ALTER TABLE link_marketing_promotion__product_type OWNER TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__product_type TO www;

COMMIT WORK;
