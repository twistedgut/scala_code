-- Auditing triggers and functions
--  This file contains the schema changes regarding the XTracker Audit Logging
--  http://animal:8080/browse/LNG
--  Jason Tang (June 2007)

BEGIN;
---------------------------------------------------------------------------
-- Changes to existing functions/schema
---------------------------------------------------------------------------
SELECT 'Changes to existing functions/schema';

ALTER TABLE product ADD operator_id INTEGER DEFAULT NULL;
ALTER TABLE product_attribute ADD operator_id INTEGER DEFAULT NULL;
ALTER TABLE price_country ADD operator_id INTEGER DEFAULT NULL;
ALTER TABLE price_default ADD operator_id INTEGER DEFAULT NULL;
ALTER TABLE price_region ADD operator_id INTEGER DEFAULT NULL;
ALTER TABLE shipping_attribute ADD operator_id INTEGER DEFAULT NULL;

SELECT 'Adding id fields to tables requiring it';
ALTER TABLE product_attribute DROP CONSTRAINT product_attribute_pkey;
ALTER TABLE product_attribute ADD UNIQUE(product_id);
ALTER TABLE product_attribute ADD id SERIAL PRIMARY KEY;

ALTER TABLE price_country DROP CONSTRAINT price_country_pkey;
ALTER TABLE price_country ADD UNIQUE(product_id,country_id);
ALTER TABLE price_country ADD id SERIAL PRIMARY KEY;

ALTER TABLE price_default DROP CONSTRAINT price_default_pkey;
ALTER TABLE price_default ADD UNIQUE(product_id);
ALTER TABLE price_default ADD id SERIAL PRIMARY KEY;

ALTER TABLE price_region DROP CONSTRAINT price_region_pkey;
ALTER TABLE price_region ADD UNIQUE(product_id,region_id);
ALTER TABLE price_region ADD id SERIAL PRIMARY KEY;

ALTER TABLE shipping_attribute DROP CONSTRAINT shipping_attribute_pkey;
ALTER TABLE shipping_attribute ADD UNIQUE(product_id);
ALTER TABLE shipping_attribute ADD id SERIAL PRIMARY KEY;



---------------------------------------------------------------------------
-- New functions/schemas additions
---------------------------------------------------------------------------

SELECT 'New functions/schemas additions';
CREATE SCHEMA audit;

CREATE TABLE audit.action (
    id              SERIAL PRIMARY KEY,
    label           TEXT,
    table_name      TEXT,
    action          TEXT,
    UNIQUE          ( table_name, action )
);


SELECT 'Populating audit.action';
INSERT INTO audit.action (id, label, table_name, action) values (
1,'Product created', 'product', 'INSERT');
INSERT INTO audit.action (id, label, table_name, action) values (
2,'Product updated', 'product', 'UPDATE');
INSERT INTO audit.action (id, label, table_name, action) values (
3,'Product deleted', 'product', 'DELETE');

INSERT INTO audit.action (id, label, table_name, action) values (
4,'Product attribute created', 'product_attribute', 'INSERT');
INSERT INTO audit.action (id, label, table_name, action) values (
5,'Product attribute updated', 'product_attribute', 'UPDATE');
INSERT INTO audit.action (id, label, table_name, action) values (
6,'Product attribute deleted', 'product_attribute', 'DELETE');

INSERT INTO audit.action (id, label, table_name, action) values (
7,'Price country created', 'price_country', 'INSERT');
INSERT INTO audit.action (id, label, table_name, action) values (
8,'Price country updated', 'price_country', 'UPDATE');
INSERT INTO audit.action (id, label, table_name, action) values (
9,'Price country deleted', 'price_country', 'DELETE');

INSERT INTO audit.action (id, label, table_name, action) values (
10,'Price default created', 'price_default', 'INSERT');
INSERT INTO audit.action (id, label, table_name, action) values (
11,'Price default updated', 'price_default', 'UPDATE');
INSERT INTO audit.action (id, label, table_name, action) values (
12,'Price default deleted', 'price_default', 'DELETE');

INSERT INTO audit.action (id, label, table_name, action) values (
13,'Price region created', 'price_region', 'INSERT');
INSERT INTO audit.action (id, label, table_name, action) values (
14,'Price region updated', 'price_region', 'UPDATE');
INSERT INTO audit.action (id, label, table_name, action) values (
15,'Price region deleted', 'price_region', 'DELETE');

INSERT INTO audit.action (id, label, table_name, action) values (
16,'Shipping attribute created', 'shipping_attribute', 'INSERT');
INSERT INTO audit.action (id, label, table_name, action) values (
17,'Shipping attribute updated', 'shipping_attribute', 'UPDATE');
INSERT INTO audit.action (id, label, table_name, action) values (
18,'Shipping attribute deleted', 'shipping_attribute', 'DELETE');


CREATE OR REPLACE FUNCTION audit.build_comment(INTEGER,INTEGER)
    RETURNS TEXT AS $$
DECLARE
    v_action_id     ALIAS FOR $1;
    v_operator_id   ALIAS FOR $2;

    v_comment       TEXT := NULL;
    v_operator_name TEXT := NULL;
BEGIN

    -- lets build together a comment about what the action is on the table
    SELECT INTO v_comment label || ' by '
    FROM audit.action WHERE id = v_action_id;

    IF v_comment IS NULL OR v_comment = ' by ' THEN
        v_comment := '<unknown action> by ';
    END IF;

    SELECT INTO v_operator_name name FROM operator WHERE id = v_operator_id;

    IF v_operator_name IS NULL OR v_operator_name = '' THEN
        v_operator_name := '<unknown>';
    END IF;

    v_comment := v_comment || v_operator_name;


    RETURN v_comment;
END;
$$ LANGUAGE plpgsql;



CREATE TABLE audit.product (
    id              SERIAL PRIMARY KEY,
    product_id      INTEGER NOT NULL,
    table_id        INTEGER,
    operator_id     INTEGER,
    action_id       INTEGER REFERENCES audit.action (id),
    comment         TEXT,
    dtm             TIMESTAMP WITH TIME ZONE DEFAULT now(),
    pushed_to_live  BOOLEAN DEFAULT FALSE
);
--  this was the original line however the integrity should be maintained by
--  the original table than the audit
--  operator_id     INTEGER NOT NULL REFERENCES operator (id),



SELECT 'Create audit trigger';
CREATE OR REPLACE FUNCTION audit.product_trigger() RETURNS
    trigger AS $$
DECLARE
    -- Variables
    v_operator_id     INTEGER := NULL;
    v_table_id        INTEGER := NULL;
    v_product_id      INTEGER := NULL;
    v_action_id       INTEGER := NULL;
    v_comment         TEXT := '''';
    v_pushed_to_live  BOOLEAN := FALSE;
    v_operator_name   TEXT := '''';
BEGIN
    -- RAISE NOTICE 'FIELDS: % %', TG_RELNAME, TG_OP;

    SELECT INTO v_action_id id FROM audit.action
        WHERE table_name = TG_RELNAME AND action = TG_OP;

    IF v_action_id IS NULL THEN
        RAISE NOTICE
            'audit_trigger: Undefined action for table: % ; action: %',
            TG_RELNAME, TG_OP;
    END IF;

    -- INSERT and UPDATE use NEW
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        v_operator_id       := NEW.operator_id;
        v_table_id          := NEW.id;
        v_product_id        := v_table_id;

        IF (NOT TG_RELNAME = 'product') THEN
            v_product_id := NEW.product_id;
        END IF;

    -- remaining option is DELETE
    ELSE
        v_operator_id       := OLD.operator_id;
        v_table_id          := OLD.id;
        v_product_id        := v_table_id;

        IF (NOT TG_RELNAME = 'product') THEN
            v_product_id := OLD.product_id;
        END IF;

    END IF;


    v_comment := audit.build_comment(v_action_id, v_operator_id);

    INSERT INTO audit.product (
        operator_id, table_id, product_id, action_id, comment, pushed_to_live
    ) VALUES (
        v_operator_id, v_table_id, v_product_id, v_action_id, v_comment,
        v_pushed_to_live
    );


    IF (TG_OP = 'DELETE') THEN

        RETURN OLD;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


SELECT 'Adding audit trigger to product';
CREATE TRIGGER product_tgr AFTER INSERT OR UPDATE OR DELETE
ON product
    FOR EACH ROW EXECUTE PROCEDURE audit.product_trigger();

SELECT 'Adding audit trigger to product_attribute';
CREATE TRIGGER product_tgr AFTER INSERT OR UPDATE OR DELETE
ON product_attribute
    FOR EACH ROW EXECUTE PROCEDURE audit.product_trigger();

SELECT 'Adding audit trigger to price_country';
CREATE TRIGGER product_tgr AFTER INSERT OR UPDATE OR DELETE
ON price_country
    FOR EACH ROW EXECUTE PROCEDURE audit.product_trigger();

SELECT 'Adding audit trigger to price_default';
CREATE TRIGGER product_tgr AFTER INSERT OR UPDATE OR DELETE
ON price_default
    FOR EACH ROW EXECUTE PROCEDURE audit.product_trigger();

SELECT 'Adding audit trigger to price_region';
CREATE TRIGGER product_tgr AFTER INSERT OR UPDATE OR DELETE
ON price_region
    FOR EACH ROW EXECUTE PROCEDURE audit.product_trigger();

SELECT 'Adding audit trigger to shipping_attribute';
CREATE TRIGGER product_tgr AFTER INSERT OR UPDATE OR DELETE
ON shipping_attribute
    FOR EACH ROW EXECUTE PROCEDURE audit.product_trigger();


COMMIT;


