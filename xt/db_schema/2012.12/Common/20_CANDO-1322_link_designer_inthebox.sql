-- CANDO-1322: Add a link table between Marketing
--             Promotions and Designers

BEGIN WORK;

CREATE TABLE link_marketing_promotion__designer (
    marketing_promotion_id      INTEGER REFERENCES marketing_promotion(id) NOT NULL,
    designer_id                 INTEGER REFERENCES designer(id) NOT NULL,
    include                     BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (marketing_promotion_id,designer_id)
);

ALTER TABLE link_marketing_promotion__designer OWNER TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__designer TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__designer TO www;

COMMIT WORK;
