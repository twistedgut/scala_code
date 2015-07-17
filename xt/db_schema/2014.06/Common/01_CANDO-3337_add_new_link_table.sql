-- CANDO-3337: Add new table to link the 'marketing_promotion'
--             table to the 'customer_category' table

BEGIN WORK;

CREATE TABLE link_marketing_promotion__customer_category (
    marketing_promotion_id      INTEGER NOT NULL REFERENCES marketing_promotion(id),
    customer_category_id        INTEGER NOT NULL REFERENCES customer_category(id),
    include                     BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (marketing_promotion_id,customer_category_id)
);
ALTER TABLE link_marketing_promotion__customer_category OWNER TO postgres;
GRANT ALL ON TABLE link_marketing_promotion__customer_category TO www;

COMMIT WORK;
