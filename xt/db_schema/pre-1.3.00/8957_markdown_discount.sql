-- Markdown & Discounting
--  This file contains the schema changes regarding the XTracker Markdown
--  http://animal:8080/browse/MDH
--  Jason Tang (June 2007)

BEGIN;
---------------------------------------------------------------------------
-- Changes to existing functions/schema
---------------------------------------------------------------------------


SELECT 'New functions/schemas additions';

CREATE SCHEMA product;

CREATE TABLE product.discount_type (
    id              SERIAL PRIMARY KEY,
    idx             INTEGER DEFAULT NULL,
    label           TEXT DEFAULT NULL,
    enabled         BOOLEAN DEFAULT TRUE
);

CREATE TRIGGER default_index_tgr AFTER INSERT OR UPDATE
ON product.discount_type
    FOR EACH ROW EXECUTE PROCEDURE public.default_index_trigger();


INSERT INTO product.discount_type ( id, label ) VALUES (
1, '1st Mark Down');
INSERT INTO product.discount_type ( id, label ) VALUES (
2, '2nd Mark Down');
INSERT INTO product.discount_type ( id, label ) VALUES (
3, '3rd Mark Down');


SELECT 'Changes to existing functions/schema';
ALTER TABLE price_adjustment ADD date_stop TIMESTAMP WITHOUT TIME ZONE;
ALTER TABLE price_adjustment ADD discount_type_id INTEGER DEFAULT NULL;


COMMIT;
