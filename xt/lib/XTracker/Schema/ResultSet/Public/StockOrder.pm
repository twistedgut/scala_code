package XTracker::Schema::ResultSet::Public::StockOrder;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use XTracker::Constants::FromDB qw( :stock_order_status );

use base 'DBIx::Class::ResultSet';

sub get_undelivered_stock {

    my ( $resultset, $start, $end, $action, $rows, $offset ) = @_;

    my $join_type   = ( $action eq "COUNT" ? "join" : "prefetch" );

    my $conds = {
        'me.status_id' => [
            $STOCK_ORDER_STATUS__ON_ORDER,
            $STOCK_ORDER_STATUS__PART_DELIVERED,
        ],
        'me.start_ship_date' => { 'between' => [ $start, $end ] },
    };
    my $args = {
        $join_type => [
            'status',
            { 'public_product' => 'designer' },
            'purchase_order',
        ],
        order_by    => 'me.start_ship_date, me.product_id asc',
    };

    if ( $action eq "COUNT" ) {
        return $resultset->count( $conds, $args );
    }
    else {
        if ( defined $rows && defined $offset ) {
            $args->{rows}   = $rows;
            $args->{offset} = $offset;
        }

        my @stock_order_rs = $resultset->search(
            $conds,
            $args
        );

        return \@stock_order_rs;
    }
}

1;
