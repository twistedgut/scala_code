package XTracker::Schema::Result::Public::VirtualProductOrderedQuantityDetails;
use strict;
use warnings;
use base qw/DBIx::Class::Core/;

# Status and other setup stuff
use XTracker::Constants::FromDB qw(
    :delivery_item_type
    :stock_order_item_status
    :stock_order_item_type
    :delivery_status
);

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('NONE');

my @columns = qw(
    variant_id
    variant_type_id
    on_order_quantity
    total_ordered_quantity
    delivered_quantity
);

sub columns { return @columns }
sub quantity_columns { return @columns[2..4] }

__PACKAGE__->add_columns(@columns);

# do not attempt to deploy() this view
__PACKAGE__->result_source_instance->is_virtual(1);

__PACKAGE__->result_source_instance->view_definition(qq[

    SELECT variant_id, max(variant_type_id) AS variant_type_id, SUM(on_order_quantity) as on_order_quantity, SUM(total_ordered_quantity) AS total_ordered_quantity, SUM(delivered_quantity) AS delivered_quantity
        FROM (
-- basis
            SELECT v.id AS variant_id, v.type_id as variant_type_id, 0 AS on_order_quantity, 0 AS total_ordered_quantity, 0 as delivered_quantity
            FROM super_variant v
            WHERE v.product_id = ?
            GROUP BY variant_id, variant_type_id

            UNION ALL

-- stock on order (minus already delivered)

-- stock_order_item
            SELECT v.id AS variant_id, 0 AS variant_type_id, soi.quantity AS on_order_quantity, 0 AS total_ordered_quantity, 0 as delivered_quantity
            FROM stock_order_item soi, variant v
            WHERE soi.variant_id = v.id
                AND v.product_id = ?
                AND soi.status_id IN ($STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                                      $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED)
                AND soi.type_id <> $STOCK_ORDER_ITEM_TYPE__SAMPLE
                AND soi.cancel = false

            UNION ALL

            SELECT v.id AS variant_id, 0 AS variant_type_id, soi.quantity AS on_order_quantity, 0 AS total_ordered_quantity, 0 as delivered_quantity
            FROM stock_order_item soi, voucher.variant v
            WHERE soi.voucher_variant_id = v.id
                AND v.voucher_product_id = ?
                AND soi.status_id IN ($STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                                      $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED)
                AND soi.type_id <> $STOCK_ORDER_ITEM_TYPE__SAMPLE
                AND soi.cancel = false

            UNION ALL

-- delivery_item

            SELECT v.id AS variant_id, 0 AS variant_type_id, -(di.quantity) AS on_order_quantity, 0 AS total_ordered_quantity, 0 as delivered_quantity
            FROM stock_order_item soi, variant v, link_delivery_item__stock_order_item link, delivery_item di
            WHERE soi.variant_id = v.id
                AND v.product_id = ?
                AND link.stock_order_item_id = soi.id
                AND link.delivery_item_id = di.id
                AND soi.status_id IN ($STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                                      $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED)
                AND soi.type_id <> $STOCK_ORDER_ITEM_TYPE__SAMPLE
                AND di.type_id = $DELIVERY_ITEM_TYPE__STOCK_ORDER
                AND soi.cancel = false

            UNION ALL

            SELECT v.id AS variant_id, 0 AS variant_type_id, -(di.quantity) AS on_order_quantity, 0 AS total_ordered_quantity, 0 as delivered_quantity
            FROM stock_order_item soi, voucher.variant v, link_delivery_item__stock_order_item link, delivery_item di
            WHERE soi.voucher_variant_id = v.id
                AND v.voucher_product_id = ?
                AND link.stock_order_item_id = soi.id
                AND link.delivery_item_id = di.id
                AND soi.status_id IN ($STOCK_ORDER_ITEM_STATUS__ON_ORDER,
                                      $STOCK_ORDER_ITEM_STATUS__PART_DELIVERED)
                AND soi.type_id <> $STOCK_ORDER_ITEM_TYPE__SAMPLE
                AND di.type_id = $DELIVERY_ITEM_TYPE__STOCK_ORDER
                AND soi.cancel = false

            UNION ALL

-- total ordered stock

            SELECT v.id AS variant_id, 0 AS variant_type_id, 0 AS on_order_quantity, soi.quantity AS total_ordered_quantity, 0 as delivered_quantity
            FROM stock_order_item soi, variant v
            WHERE soi.variant_id = v.id
                AND v.product_id = ?
                AND soi.type_id <> $STOCK_ORDER_ITEM_TYPE__SAMPLE
                AND soi.cancel = false

            UNION ALL

            SELECT v.id AS variant_id, 0 AS variant_type_id, 0 AS on_order_quantity, soi.quantity AS total_ordered_quantity, 0 as delivered_quantity
            FROM stock_order_item soi, voucher.variant v
            WHERE soi.voucher_variant_id = v.id
                AND v.voucher_product_id = ?
                AND soi.type_id <> $STOCK_ORDER_ITEM_TYPE__SAMPLE
                AND soi.cancel = false

            UNION ALL

            SELECT v.id AS variant_id, 0 AS variant_type_id, 0 AS on_order_quantity, 0 AS total_ordered_quantity,
                SUM(CASE WHEN d.status_id = $DELIVERY_STATUS__NEW THEN di.packing_slip ELSE di.quantity END) AS delivered_quantity
            FROM variant v
            JOIN stock_order_item soi ON soi.variant_id = v.id
            JOIN link_delivery_item__stock_order_item ldisoi ON ldisoi.stock_order_item_id = soi.id
            JOIN delivery_item di ON di.id = ldisoi.delivery_item_id
            JOIN delivery d ON d.id = di.delivery_id
            WHERE v.product_id = ?
                AND d.cancel IS FALSE
                AND di.cancel IS FALSE
                AND d.status_id IN (
                    $DELIVERY_STATUS__NEW,
                    $DELIVERY_STATUS__COUNTED
                )
                AND soi.type_id <> $STOCK_ORDER_ITEM_TYPE__SAMPLE
                AND di.type_id = $DELIVERY_ITEM_TYPE__STOCK_ORDER
            GROUP BY v.id

            UNION ALL

            SELECT v.id AS variant_id, 0 AS variant_type_id, 0 AS on_order_quantity, 0 AS total_ordered_quantity,
                SUM(CASE WHEN d.status_id = $DELIVERY_STATUS__NEW THEN di.packing_slip ELSE di.quantity END) AS delivered_quantity
            FROM voucher.variant v
            JOIN stock_order_item soi ON soi.voucher_variant_id = v.id
            JOIN link_delivery_item__stock_order_item ldisoi ON ldisoi.stock_order_item_id = soi.id
            JOIN delivery_item di ON di.id = ldisoi.delivery_item_id
            JOIN delivery d ON d.id = di.delivery_id
            WHERE v.voucher_product_id = ?
                AND d.cancel IS FALSE
                AND di.cancel IS FALSE
                AND d.status_id IN (
                    $DELIVERY_STATUS__NEW,
                    $DELIVERY_STATUS__COUNTED
                )
                AND soi.type_id <> $STOCK_ORDER_ITEM_TYPE__SAMPLE
                AND di.type_id = $DELIVERY_ITEM_TYPE__STOCK_ORDER
            GROUP BY v.id

        ) AS details
    GROUP BY variant_id

]);


1;
