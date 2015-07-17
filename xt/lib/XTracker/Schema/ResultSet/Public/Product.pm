package XTracker::Schema::ResultSet::Public::Product;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw{
    :recommended_product_type
    :stock_process_status
};

sub get_promotion_products {
    my($resultset, $channel_ids, $seasons, $designers, $prodtypes, $pids) = @_;

    my $cond = {};
    $cond->{'product_channel.live'} = 1;
    $cond->{'product_channel.channel_id'} = { in => $channel_ids };

    if (defined $seasons and ref($seasons) and scalar @$seasons) {
        $cond->{season_id} = { in => $seasons };
    }

    if (defined $designers and ref($designers) and scalar @$designers) {
        $cond->{designer_id} = { in => $designers };
    }

    if (defined $prodtypes and ref($prodtypes) and scalar @$prodtypes) {
        $cond->{product_type_id} = { in => $prodtypes };
    }

    if (defined $pids and ref($pids) and scalar @$pids) {
        $cond->{'me.id'} = { in => $pids };
    }

    my $rs = $resultset->search( $cond, { join => [qw/product_channel/]} );

    return $rs;
}

sub incomplete_putaway_processes {
    my ( $rs, $pid ) = @_;
    my $sp_conditions = {
        'stock_processes.status_id' => [
            $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
            $STOCK_PROCESS_STATUS__APPROVED,
        ],
        'stock_processes.complete'  => 0,
        'stock_processes.quantity'  => { '>' => 0 },
    };
    my $sp_columns = {
        'columns' => [qw(id quantity group_id)],
    };

    my $variant_rs = $rs->search({ 'me.id' => $pid })
                        ->related_resultset('variants');

    # stock order putaways
    my $stock_order_rs = $variant_rs
        ->related_resultset('stock_order_items')
        ->related_resultset('link_delivery_item__stock_order_items')
        ->related_resultset('delivery_item')
        ->search_related( 'stock_processes', $sp_conditions, $sp_columns );

    # out of quarantine putaways
    my $quarantine_rs = $variant_rs
        ->related_resultset('quarantine_processes')
        ->related_resultset('link_delivery_item__quarantine_processes')
        ->related_resultset('delivery_item')
        ->search_related( 'stock_processes', $sp_conditions, $sp_columns );

    # sample transfer return putaways
    my $sample_transfer_rs = $variant_rs
        ->related_resultset('shipment_items')
        ->related_resultset('link_delivery_item__shipment_items')
        ->related_resultset('delivery_item')
        ->search_related( 'stock_processes', $sp_conditions, $sp_columns );

    # customer return putaways
    my $customer_return_rs = $variant_rs
        ->related_resultset('return_items')
        ->related_resultset('link_delivery_item__return_items')
        ->related_resultset('delivery_item')
        ->search_related( 'stock_processes', $sp_conditions, $sp_columns );

    # union all of the result sets
    my $union = $stock_order_rs->union([$quarantine_rs, $sample_transfer_rs, $customer_return_rs]);
    return wantarray ? $union->all : $union;
}

1;
