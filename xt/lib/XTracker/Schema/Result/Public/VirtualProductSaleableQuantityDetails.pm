package XTracker::Schema::Result::Public::VirtualProductSaleableQuantityDetails;
use strict;
use warnings;
use base qw/DBIx::Class::Core/;

# Status and other setup stuff
use XTracker::Constants::FromDB qw(
    :flow_status
    :reservation_status
    :shipment_item_status
);

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('NONE');

# The columns for our view, generated from various things and munged together

# hackish: get the values we want from the constants
my @status = map { ${$XTracker::Constants::FromDB::{substr($_,1)}} }
    grep { /__STOCK_STATUS$/ }
    @XTracker::Constants::FromDB::FLOW_STATUS_LIST;

my @more_quants = qw(saleable_quantity
                     allocated_quantity
                     shipment_cancelled_quantity
                     reserved_quantity);
sub non_status_columns { return @more_quants }
sub status_colname { "status_$_[0]_quantity" }
my @columns = (
    qw(channel_id variant_id variant_type_id),
    @more_quants,
    (
        map { status_colname($_) } @status
    ),
);
__PACKAGE__->add_columns(@columns);

# do not attempt to deploy() this view
__PACKAGE__->result_source_instance->is_virtual(1);

# Snippets of reusable, generated SQL, all in the form of
# comma seperated list of `value as quantity` statements

# all quantities set to 0
my $more_q_zero = join ', ',
    (map { "0 as $_" } @more_quants);

# all status set to 0
my $status_q_zero = join ', ',
    (map {
        "0 as ".status_colname($_)
    } @status);

# saleable_quantity is q.quantity if q.status_id is main stock, otherwise 0
# every other quantity is 0
my $more_q_select = join ', ',
    (map { ($_ eq 'saleable_quantity' ? "case when q.status_id = $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS then q.quantity else 0 end" : "0")." as $_" } @more_quants);

# if q.status_id is the status, status is q.quantity, otherwise 0
my $status_q_select = join ', ',
    (map {
        "case when q.status_id=$_ then q.quantity else 0 end as ".status_colname($_)
    } @status);

# munge the status and quantity and output a list of `sum(quantity) as quantity`
my $sum_select = join ', ',
    map { "sum($_) as $_" } (@more_quants,(map { status_colname($_) } @status));

# SQL to create the view / fill the columns
# calculated as : total stock - (reservations + ordered not picked)
__PACKAGE__->result_source_instance->view_definition(qq[
    SELECT channel_id, variant_id, max(variant_type_id) as variant_type_id, $sum_select
        FROM (
-- basis
            SELECT ch.id AS channel_id, v.id AS variant_id, v.type_id as variant_type_id, $more_q_zero, $status_q_zero
            FROM super_variant v, channel ch
            WHERE v.product_id = ?
            GROUP BY ch.id, variant_id, variant_type_id

            UNION ALL

-- by status
            SELECT q.channel_id, q.variant_id, 0 as variant_type_id, $more_q_select, $status_q_select
            FROM quantity q, super_variant v
            WHERE q.variant_id = v.id
                AND v.product_id = ?

            UNION ALL

-- reservations
            SELECT r.channel_id, r.variant_id, 0 as variant_type_id, -count(r.*) as saleable_quantity, 0 as allocated_quantity, 0 as shipment_cancelled_quantity, count(r.*) AS reserved_quantity, $status_q_zero
            FROM reservation r, super_variant v
            WHERE r.variant_id = v.id
                AND v.product_id = ?
                AND r.status_id = $RESERVATION_STATUS__UPLOADED
            GROUP BY r.channel_id, r.variant_id

            UNION ALL

-- allocated, customer order
            SELECT o.channel_id, v.id AS variant_id, 0 as variant_type_id, -count(si.*) as saleable_quantity, count(si.*) AS allocated_quantity, 0 as shipment_cancelled_quantity, 0 as reserved_quantity, $status_q_zero
            FROM shipment_item si, super_variant v, shipment s, link_orders__shipment link, orders o
            WHERE (si.variant_id = v.id or si.voucher_variant_id = v.id )
                AND v.product_id = ?
                AND si.shipment_item_status_id IN ($SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED)
                AND si.shipment_id = s.id
                AND s.id = link.shipment_id
                AND link.orders_id = o.id
            GROUP BY o.channel_id, v.id

            UNION ALL

-- allocated, sample orders
            SELECT st.channel_id, v.id AS variant_id, 0 as variant_type_id, -count(si.*) as saleable_quantity, count(si.*) AS allocated_quantity, 0 as shipment_cancelled_quantity, 0 as reserved_quantity, $status_q_zero
            FROM shipment_item si, super_variant v, shipment s, link_stock_transfer__shipment link, stock_transfer st
            WHERE (si.variant_id = v.id or si.voucher_variant_id = v.id )
                AND v.product_id = ?
                AND si.shipment_item_status_id IN ($SHIPMENT_ITEM_STATUS__NEW, $SHIPMENT_ITEM_STATUS__SELECTED)
                AND si.shipment_id = s.id
                AND s.id = link.shipment_id
                AND link.stock_transfer_id = st.id
            GROUP BY st.channel_id, v.id
        ) AS details
    GROUP BY channel_id, variant_id
]);

1;
