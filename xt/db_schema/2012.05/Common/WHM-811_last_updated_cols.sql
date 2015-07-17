-- Add last_updated columns to orders, shipment and shipment_item, and triggers
-- to update them

BEGIN;

    -- Disable triggers to speed up updates
    ALTER TABLE shipment_item DISABLE TRIGGER ALL;

-- ORDERS table
  -- drop indexes on orders table

    drop index orders_customer_id;
    drop index orders_date;
    drop index orders_idx_channel_id;
    drop index orders_order_nr;
    drop index orders_order_status_id;

    -- Add new columns
    ALTER TABLE orders ADD COLUMN last_updated timestamp with time zone;
    UPDATE orders SET last_updated = date;
    ALTER TABLE orders
        ALTER last_updated SET NOT NULL,
        ALTER last_updated SET DEFAULT now();

    -- add indexes back.
    create index orders_order_status_id on orders (order_status_id);
    create index orders_customer_id on orders (customer_id);
    create index orders_date on orders (date);
    create index orders_idx_channel_id on orders (channel_id);
    create index orders_order_nr on orders (order_nr);

-- Shipment table

--drop indexes

    drop index idx_shipment_delivered;
    drop index idx_shipment_return_airway_bill;
    drop index idx_shipment_telephone;
    drop index shipment_address;
    drop index shipment_outward_awb_idx;
    drop index shipment_shipment_class_id;
    drop index shipment_shipment_status_id;


    ALTER TABLE shipment ADD COLUMN last_updated timestamp with time zone;
    UPDATE shipment SET last_updated = date;
    ALTER TABLE shipment
        ALTER last_updated SET NOT NULL,
        ALTER last_updated SET DEFAULT now();
    -- add indexes back
    create index idx_shipment_delivered on shipment (delivered);
    create index idx_shipment_return_airway_bill  on shipment (return_airway_bill);
    create index idx_shipment_telephone  on shipment (telephone);
    create index shipment_address  on shipment (shipment_address_id);
    create index shipment_outward_awb_idx  on shipment (outward_airway_bill);
    create index shipment_shipment_class_id  on shipment (shipment_class_id);
    create index shipment_shipment_status_id  on shipment (shipment_status_id);


-- shipment_item table

    -- drop indexes
    drop index shipment_item_container_index;
    drop index shipment_item_shipment_box_id_idx;
    drop index shipment_item_shipment_id;
    drop index shipment_item_shipment_item_status_id;
    drop index shipment_item_variant_id;
    drop index voucher_variant_id;

    ALTER TABLE shipment_item ADD COLUMN last_updated timestamp with time zone;
    UPDATE shipment_item si SET last_updated = s.date FROM shipment s
        WHERE s.id = si.shipment_id;
    ALTER TABLE shipment_item
        ALTER last_updated SET NOT NULL,
        ALTER last_updated SET DEFAULT now();

     -- add indexes back
    create index shipment_item_container_index on shipment_item (container_id);
    create index shipment_item_shipment_box_id_idx on shipment_item (shipment_box_id);
    create index shipment_item_shipment_id on shipment_item (shipment_id);
    create index shipment_item_shipment_item_status_id on shipment_item (shipment_item_status_id);
    create index shipment_item_variant_id on shipment_item (variant_id);
    create index voucher_variant_id on shipment_item (voucher_variant_id);


-- New indexes

    -- Add indexes
    CREATE INDEX ix_public_orders_last_updated ON orders(last_updated);
    CREATE INDEX ix_public_shipment_last_updated ON shipment(last_updated);
    CREATE INDEX ix_public_shipment_item_last_updated ON shipment_item(last_updated);

    -- Create the function
    CREATE OR REPLACE FUNCTION last_updated_func() RETURNS TRIGGER AS $$
        BEGIN
            NEW.last_updated := clock_timestamp();
            RETURN NEW;
        END;
    $$
    LANGUAGE 'plpgsql';

    -- Add the triggers
    CREATE TRIGGER orders_last_updated_tr BEFORE UPDATE ON orders
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();
    CREATE TRIGGER shipment_last_updated_tr BEFORE UPDATE ON shipment
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();
    CREATE TRIGGER shipment_item_last_updated_tr BEFORE UPDATE ON shipment_item
        FOR EACH ROW EXECUTE PROCEDURE last_updated_func();

    -- Re-enable triggers to speed up updates
    ALTER TABLE shipment_item ENABLE TRIGGER ALL;

COMMIT;
