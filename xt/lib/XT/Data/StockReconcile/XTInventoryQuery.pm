package XT::Data::StockReconcile::XTInventoryQuery;
# vim: set ts=4 sw=4 sts=4:
use strict;
use warnings;
use namespace::autoclean;

use NAP::policy "tt", 'class';
use XTracker::Constants::FromDB qw(
    :flow_status
    :stock_order_type
    :stock_process_type
    :stock_process_status
    :return_item_status
    :shipment_class
    :product_channel_transfer_status
    :shipment_item_status
    :allocation_item_status
);

# Returns a string which is the SQL to dump XTracker's stock.
# Only used for PRL reconciliation at the moment.
sub gen_queries {
  my ($location) = @_;

  return qq{
        -- all products and gift vouchers - selecting client_prl_name, sku, status
          -- product
          CREATE TEMP TABLE prl_reconciliation_data AS
          SELECT cl.prl_name AS client_prl_name,
                 v.product_id || '-' || sku_padding(v.size_id) AS sku,
                 CASE
                 WHEN fs.id =   $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS          THEN 'MAIN'
                 WHEN fs.id =   $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS          THEN 'DEAD'
                 WHEN fs.id IN ($FLOW_STATUS__QUARANTINE__STOCK_STATUS,
                                $FLOW_STATUS__RTV_GOODS_IN__STOCK_STATUS)       THEN 'FAULTY'
                 WHEN fs.id IN ($FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
                                $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
                                $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS)    THEN 'RTV'
                 ELSE UPPER(fs.name)
                 END AS status,
                 SUM(q.quantity) AS available,
                 0   AS allocated_pre_picked
            FROM variant v
            JOIN quantity q     ON v.id=q.variant_id
            JOIN flow.status fs ON fs.id=q.status_id
            JOIN channel c      ON q.channel_id=c.id
            JOIN business b     ON c.business_id=b.id
            JOIN client cl      ON b.client_id=cl.id
            JOIN location l     ON q.location_id=l.id
           WHERE fs.id IN ($FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                           $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS)
             AND l.location = '$location'
           GROUP BY client_prl_name,
                    sku,
                    status,
                    allocated_pre_picked
           ;
         },
         qq{
          -- gift vouchers
          INSERT INTO prl_reconciliation_data
          SELECT cl.prl_name AS client_prl_name,
                 v.voucher_product_id || '-999' AS sku,
                 'MAIN' AS status,
                 SUM(q.quantity) AS available,
                 0   AS allocated_pre_picked
            FROM voucher.variant v
            JOIN quantity q     ON v.id=q.variant_id
            JOIN flow.status fs ON fs.id=q.status_id
            JOIN channel c      ON q.channel_id=c.id
            JOIN business b     ON c.business_id=b.id
            JOIN client cl      ON b.client_id=cl.id
            JOIN location l     ON q.location_id=l.id
           WHERE l.location = '$location'
           GROUP BY client_prl_name,
                    sku,
                    status,
                    allocated_pre_picked
           ;
         },
         qq{
        -- select product and voucher allocated_pre_picked
          -- allocated pre-picked product stock
          INSERT INTO prl_reconciliation_data
          SELECT cl.prl_name AS client_prl_name,
                 v.product_id || '-' || sku_padding(v.size_id) AS sku,
                 CASE s.shipment_class_id
                 WHEN $SHIPMENT_CLASS__RTV_SHIPMENT THEN 'RTV'
                 ELSE                                    'MAIN' -- we ship samples from main
                 END AS status,
                 0 AS available,
                 COUNT(si.id) AS allocated_pre_picked
           FROM shipment_item si
              JOIN shipment s                ON si.shipment_id=s.id
              JOIN variant v                 ON si.variant_id=v.id
              LEFT OUTER JOIN link_stock_transfer__shipment as lsts on s.id = lsts.shipment_id
              LEFT OUTER JOIN stock_transfer st         ON lsts.stock_transfer_id=st.id
              LEFT OUTER JOIN link_orders__shipment los ON si.shipment_id=los.shipment_id
              LEFT OUTER JOIN orders o                  ON los.orders_id=o.id
              JOIN channel c                 ON coalesce(o.channel_id, st.channel_id) = c.id
              JOIN business b     ON c.business_id=b.id
              JOIN client cl      ON b.client_id=cl.id
              JOIN quantity q                ON v.id=q.variant_id
              JOIN location l                ON q.location_id=l.id
              JOIN allocation_item ai        ON ai.shipment_item_id = si.id
           WHERE ai.status_id IN (
                    $ALLOCATION_ITEM_STATUS__ALLOCATED,
                    $ALLOCATION_ITEM_STATUS__PICKING
                 )
             AND l.location = '$location'
             AND q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS
             AND s.shipment_class_id != $SHIPMENT_CLASS__RTV_SHIPMENT
           GROUP BY client_prl_name,
                    sku,
                    status,
                    available
           ;
         },
         qq{
          -- allocated pre-picked voucher stock
          INSERT INTO prl_reconciliation_data
          SELECT cl.prl_name AS client_prl_name,
                 v.voucher_product_id || '-999' AS sku,
                 'MAIN' AS status,
                 0 AS available,
                 COUNT(si.id) AS allocated_pre_picked
            FROM shipment_item si
            JOIN shipment s                ON si.shipment_id=s.id
            JOIN voucher.variant v         ON si.variant_id=v.id
            JOIN link_orders__shipment los ON si.shipment_id=los.shipment_id
            JOIN orders o                  ON los.orders_id=o.id
            JOIN channel c                 ON o.channel_id=c.id
            JOIN business b     ON c.business_id=b.id
            JOIN client cl      ON b.client_id=cl.id
            JOIN quantity q                ON v.id=q.variant_id
            JOIN location l                ON q.location_id=l.id
            JOIN allocation_item ai        ON ai.shipment_item_id = si.id
          WHERE ai.status_id IN (
                    $ALLOCATION_ITEM_STATUS__ALLOCATED,
                    $ALLOCATION_ITEM_STATUS__PICKING
                 )
             AND l.location = '$location'
             AND s.shipment_class_id != $SHIPMENT_CLASS__RTV_SHIPMENT
           GROUP BY client_prl_name,
                    sku,
                    status,
                    available
           ;
         },
         qq{
            SELECT client_prl_name,
                   sku,
                   status,
                   SUM(allocated_pre_picked)             AS allocated,
                   SUM(available - allocated_pre_picked) AS available
            FROM prl_reconciliation_data
            GROUP BY client_prl_name,
                     sku,
                     status
            ORDER BY sku,
                     client_prl_name
         ;
         },
}

1;
