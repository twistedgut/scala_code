BEGIN TRANSACTION;

CREATE OR REPLACE FUNCTION superview_upgrade_func()
RETURNS TEXT AS $$
DECLARE v_column_exists integer := 0;
BEGIN

    -- protection from running script twice (so this
    -- can be deployed and also go into db_schema for
    -- other stuff too)

    SELECT 1 INTO v_column_exists
    FROM information_schema.columns
    WHERE table_name = 'variant' and column_name='vtype';

    IF v_column_exists = 1 THEN
        -- no db changes to make.
        RETURN 'Super_variant patch has already been previously applied successfully';
    END IF;

    -- Now we are going to make both variant and voucher variant
    -- tables fit the same table schema. this is the schema that
    -- the super_variant view uses.

    -- see it's last definition here:
    --    db_schema/2010.23/Common/04_super_variant.sql

    ALTER TABLE variant
        ADD vtype text not null default 'product' constraint v_vtype_must_be_product CHECK (vtype = 'product');

    ALTER TABLE voucher.variant
        ADD product_id integer,
        ADD size_id_old integer not null default 22 constraint vv_size_id_old_must_be_default CHECK (size_id_old = 22),
        ADD nap_size_id integer not null default 0 constraint vv_nap_size_id_must_be_default CHECK (nap_size_id = 0),
        ADD legacy_sku varchar(255),
        ADD type_id integer not null default 1 constraint vv_type_id_must_be_default CHECK (type_id = 1),
        ADD size_id integer not null default 999 constraint vv_size_id_must_be_default CHECK (size_id = 999),
        ADD designer_size_id integer not null default 0 constraint vv_designer_size_id_must_be_default CHECK (designer_size_id = 0),
        ADD std_size_id integer not null default 4 constraint vv_std_size_id_must_be_default CHECK (std_size_id = 4),
        ADD vtype text not null default 'voucher' constraint vv_vtype_must_be_voucher CHECK (vtype = 'voucher');

    -- back fill non default data

    UPDATE voucher.variant SET
        product_id = voucher_product_id,
        legacy_sku = voucher_product_id || '-999';

    -- apply constraints (trigger sets these values to non-null when rows are inserted)

    ALTER TABLE voucher.variant
        ALTER COLUMN product_id SET NOT NULL,
        ALTER COLUMN legacy_sku SET NOT NULL;

    ALTER TABLE voucher.variant
        ADD CONSTRAINT vv_product_id_eq_voucher_product_id CHECK (product_id = voucher_product_id),
        ADD CONSTRAINT vv_legacy_sku_fake_value CHECK (legacy_sku = (voucher_product_id || '-999')::varchar);

    -- now variant and voucher variant look like what
    -- super_variant view originally wanted!

    -- we can't default these fields that are based on
    -- other columns passed in, so we use a trigger to
    -- do this.

    -- now inserts work as they always have for those tables and the view
    -- at this point is effectively reduced to a "select variant union all voucher.variant;
    -- with no inline manipulation.

    -- for, you know, performance
    CREATE INDEX voucher__variant__product_id_idx on voucher.variant(product_id);

    -- We remove the super_variant view and construct a super_variant table
    -- that variant/voucher variant inherit from, meaning "select * from super_variant"
    -- returns the same data as it did before but through a more effecient means.

    DROP VIEW super_variant;

    CREATE TABLE super_variant AS select * FROM variant LIMIT 0;
    GRANT SELECT ON super_variant TO www;

    ALTER TABLE variant inherit super_variant;
    ALTER TABLE voucher.variant inherit super_variant;

    -- now performance of SELECT * FROM super_variant is much quicker.

    RETURN 'The Super_variant patch is now active';

END;
$$
LANGUAGE 'plpgsql';

SELECT superview_upgrade_func();
DROP FUNCTION superview_upgrade_func();

CREATE OR REPLACE FUNCTION voucher__variant__set_default_fields_func()
RETURNS TRIGGER AS $$
BEGIN

    NEW.product_id = NEW.voucher_product_id;
    NEW.legacy_sku = NEW.voucher_product_id || '-999';

    return NEW;

END;
$$
LANGUAGE 'plpgsql';

DROP TRIGGER IF EXISTS voucher__variant__set_default_fields_tgr ON voucher.variant;
CREATE TRIGGER voucher__variant__set_default_fields_tgr
BEFORE INSERT OR UPDATE ON voucher.variant
FOR EACH ROW EXECUTE PROCEDURE voucher__variant__set_default_fields_func();

COMMIT TRANSACTION;
