package XTracker::Schema::ResultSet::Public::SuperPurchaseOrder;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';
use Carp;
use Data::Dump 'pp';
use Perl6::Junction 'none';

use XTracker::Constants::FromDB qw{
    :variant_type
    :recommended_product_type
    :purchase_order_status
};

# returns list of child resultsets

sub incomplete {
    my ($self) = @_;

    my $me = $self->current_source_alias;

    $self->search_rs(
        { "$me.status_id" => { '<' => $PURCHASE_ORDER_STATUS__DELIVERED } },
        { order_by => "$me.id" },
    );
}


sub stock_in_search {
    my ($self, $q, @params) =  @_;
    my $schema = $self->result_source->schema;

    $q->{status_id} = {'<' => $q->{status_id}}
        if exists $q->{status_id};

    if ($q->{purchase_order_number}) {
        $q->{purchase_order_number} =
            {ILIKE => "%$q->{purchase_order_number}%"};
    }

    if (my $pid = delete $q->{product_id}) {
        my $so = $schema->resultset('Public::StockOrder')->search( [
            {product_id=>$pid},
            {voucher_product_id=>$pid}
        ] );
        $q->{"me.id"} = { 'IN' => $so->get_column('purchase_order_id')->as_query };
    }

    if (my $vid = delete $q->{variant_id}) {
        my $so = $schema->resultset('Public::StockOrderItem')->search(
            {variant_id=>$vid},
        )->related_resultset('stock_order');
        $q->{"me.id"} = { 'IN' => $so->get_column('purchase_order_id')->as_query };
    }

    if (my $sn = delete $q->{style_number}) {
        my $pq = $schema->resultset('Public::Product')->search({style_number=>{'ILIKE'=>"%$sn%"}});
        my $po = $schema->resultset('Public::StockOrder')->search({product_id=>{
                IN => $pq->get_column('id')->as_query
            }});
        $q->{"me.id"} = { 'IN' => $po->get_column('purchase_order_id')->as_query };
    }

    return $self->search($q, @params);
}

1;
