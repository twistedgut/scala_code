package XTracker::Database::PreOrder;
use strict;
use warnings;

use Perl6::Export::Attrs;
use Readonly;

use XTracker::Constants::FromDB qw( :pre_order_item_status );

sub get_pre_order_number_from_id :Export(:utils) {
    return sprintf('P%d',shift);
}

sub get_pre_order_id_from_number :Export(:utils) {
    if ($_[0] =~ m/^p(?<id>\d+)$/i) {
        return $+{id};
    }
    else {
        return;
    }
}

sub get_pre_order_id_from_number_or_id :Export(:utils) {
    if ($_[0] =~ m/^p?(?<id>\d+)$/i) {
        return $+{id};
    }
    else {
        return;
    }
}

sub is_valid_pre_order_number :Export(:validation) {
    return get_pre_order_id_from_number(shift) ? 1 : 0 ;
}

sub get_pre_order_by_number :Export(:utils) {
    my ($schema, $number) = @_;

    my $pre_order_id = get_pre_order_id_from_number($number);

    die "Not a valid pre_order number\n"
        unless $pre_order_id;

    return $schema->resultset( 'Public::PreOrder' )
                  ->find( { id => $pre_order_id } );
}

sub get_pre_order_items_awaiting_orders :Export(:utils) {
    my ($schema, $interval) = @_;

    my @list = ();

    my $rs = $schema->resultset('Public::PreOrderItem');

    # slightly uncomfortable with the inclusion of $interval
    # is there a way to do ? substitution as part of the selectall_array call?

    my $qry = qq{
      SELECT id FROM (
        SELECT    poi.id,
                  MAX(poilog.date) AS export_date,
                  poi.pre_order_id
        FROM      pre_order_item AS poi
        LEFT JOIN link_shipment_item__reservation AS sir
               ON sir.reservation_id = poi.reservation_id
        LEFT JOIN pre_order_item_status_log AS poilog
               ON poilog.pre_order_item_id = poi.id
              AND poi.pre_order_item_status_id = ?
              AND poilog.pre_order_item_status_id = poi.pre_order_item_status_id
        WHERE     sir.shipment_item_id IS NULL
        GROUP BY  poi.id,
                  poi.pre_order_id
        HAVING    MAX(poilog.date) < (NOW() - INTERVAL '$interval')
        ORDER BY  export_date,
                  pre_order_id,
                  id
      ) AS foo
    };

    my $ids = $schema->storage->dbh->selectall_arrayref($qry, undef, $PRE_ORDER_ITEM_STATUS__EXPORTED);

    foreach my $id (@{$ids}) {
        push @list, $rs->find( $id->[0] );
    }

    return \@list;
}

1;
