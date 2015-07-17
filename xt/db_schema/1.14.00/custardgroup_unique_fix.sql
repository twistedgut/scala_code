-- we need to extend the UNIQUE key to cover three columns, not two
--
-- http://jira:8080/browse/XTR-774
BEGIN WORK;

    ALTER TABLE promotion.customer_customergroup
    DROP CONSTRAINT customer_customergroup_customer_id_key;

    ALTER TABLE promotion.customer_customergroup
    ADD UNIQUE(customer_id,customergroup_id,website_id);

COMMIT;
