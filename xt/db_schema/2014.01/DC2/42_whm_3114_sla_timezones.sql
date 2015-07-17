-- Add time zones to SLA related timestamp columns missing them
BEGIN;
    -- Disable 'last_updated' triggers
    ALTER TABLE orders DISABLE TRIGGER orders_last_updated_tr;
    ALTER TABLE shipment DISABLE TRIGGER shipment_last_updated_tr;

    -- Drop these views that relies on the orders.date column. We'll recreate them afterwards
    DROP VIEW IF EXISTS vw_sale_orders_outnet;
    DROP VIEW IF EXISTS vw_sale_orders;
    DROP VIEW IF EXISTS njiv_orders2;

    -- Should already be dropped
    DROP VIEW IF EXISTS "njiv_ftbc_gross_sales_OLD";

    ALTER TABLE orders ALTER COLUMN date SET DATA TYPE TIMESTAMP WITH TIME ZONE USING date AT TIME ZONE 'America/New_York';

    ALTER TABLE shipment ALTER COLUMN date SET DATA TYPE TIMESTAMP WITH TIME ZONE USING date AT TIME ZONE 'America/New_York';
    ALTER TABLE shipment ALTER COLUMN sla_cutoff SET DATA TYPE TIMESTAMP WITH TIME ZONE USING sla_cutoff AT TIME ZONE 'America/New_York';

    CREATE OR REPLACE VIEW vw_sale_orders_outnet AS
    SELECT all_sale.date, all_sale.order_nr, all_sale.units AS order_items, 'sale_order'::text AS sale_order
   FROM ( SELECT o.date, o.order_nr, count(si.id) AS units
           FROM orders o
      JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON s.id = los.shipment_id
   JOIN shipment_item si ON s.id = si.shipment_id
   JOIN link_shipment_item__price_adjustment lsipa ON si.id = lsipa.shipment_item_id
  WHERE o.channel_id = 4 AND s.shipment_class_id = 1
  GROUP BY o.date, o.order_nr) all_sale
   JOIN ( SELECT o.date, o.order_nr, count(si.id) AS units
           FROM orders o
      JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON s.id = los.shipment_id
   JOIN shipment_item si ON s.id = si.shipment_id
  WHERE o.channel_id = 4 AND s.shipment_class_id = 1
  GROUP BY o.date, o.order_nr) all_prod ON all_sale.order_nr::text = all_prod.order_nr::text
  WHERE all_sale.units = all_prod.units
  ORDER BY all_sale.order_nr;

  ALTER TABLE vw_sale_orders_outnet OWNER TO www;


    CREATE OR REPLACE VIEW vw_sale_orders AS
    SELECT all_sale.date, all_sale.order_nr, all_sale.units AS order_items, 'sale_order'::text AS sale_order
   FROM ( SELECT o.date, o.order_nr, count(si.id) AS units
           FROM orders o
      JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON s.id = los.shipment_id
   JOIN shipment_item si ON s.id = si.shipment_id
   JOIN link_shipment_item__price_adjustment lsipa ON si.id = lsipa.shipment_item_id
  WHERE o.channel_id = 2 AND s.shipment_class_id = 1
  GROUP BY o.date, o.order_nr) all_sale
   JOIN ( SELECT o.date, o.order_nr, count(si.id) AS units
           FROM orders o
      JOIN link_orders__shipment los ON o.id = los.orders_id
   JOIN shipment s ON s.id = los.shipment_id
   JOIN shipment_item si ON s.id = si.shipment_id
  WHERE o.channel_id = 2 AND s.shipment_class_id = 1
  GROUP BY o.date, o.order_nr) all_prod ON all_sale.order_nr::text = all_prod.order_nr::text
  WHERE all_sale.units = all_prod.units
  ORDER BY all_sale.order_nr;

    ALTER TABLE vw_sale_orders OWNER TO www;

    -- Now safe to reenable the triggers
    ALTER TABLE orders ENABLE TRIGGER orders_last_updated_tr;
    ALTER TABLE shipment ENABLE TRIGGER shipment_last_updated_tr;
COMMIT;