package Test::XTracker::Data::PreOrder;

use NAP::policy     qw( test );

use List::Util 'sum';

use Test::XTracker::Data;
use Test::XT::Data;

use XTracker::Constants::FromDB     qw(
                                        :pre_order_status
                                        :pre_order_item_status
                                        :pre_order_refund_status
                                        :reservation_status
                                    );


=head1 NAME

Test::XTracker::Data::PreOrder - To do Pre-Order Related Stuff

=head1 SYNOPSIS

    package Test::Foo;

    use Test::XTracker::Data::PreOrder;

    Test::XTracker::Data::PreOrder->create_complete_pre_order;

=cut

=head1 METHODS

=head2 create_complete_pre_order

    $pre_ord_obj    = __PACKAGE__->create_complete_pre_order( {
                                                            # optional arguments
                                                            with_no_status_logs     => 1,
                                                        } );

Will create a 'Complete' Pre-Order using 'Test::XT::Data::PreOrder'.

If you need to alter stuff for the Pre-Order such as Channel or use
a particular Customer, then please pass arguments to this method and
change the code to use them accordingly, just make sure it still does
the expected thing when passed with NO arguments.

=cut

sub create_complete_pre_order {
    my $self    = shift;
    my $args    = shift;

    my $framework   = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );

    ARGS:
    foreach my $accessor ( keys %{ $args } ) {
        next ARGS       if ( !$framework->can( $accessor ) );
        $framework->$accessor( $args->{ $accessor } );
    }

    my $pre_order   = $framework->pre_order;

    if ( $args->{with_no_status_logs} ) {
        $pre_order->pre_order_status_logs->delete;
        $pre_order->pre_order_items->search_related('pre_order_item_status_logs')->delete;
    }

    return $pre_order->discard_changes;
}

=head2 create_complete_pre_order_but_without_reservations

=cut

sub create_complete_pre_order_but_without_reservations {
    my $self = shift;

    my $framework = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );

    $framework->create_reservations(0);

    return $framework->pre_order;
}

=head2 create_incomplete_pre_order

=cut

sub create_incomplete_pre_order {
    my ( $self, $args ) = @_;

    my $framework = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );
    $framework->create_reservations(0);
    $framework->create_payment(0);
    $framework->pre_order_status($PRE_ORDER_STATUS__INCOMPLETE);
    $framework->pre_order_item_status($PRE_ORDER_ITEM_STATUS__SELECTED);

    ARGS:
    foreach my $accessor ( keys %{ $args } ) {
        next ARGS       if ( !$framework->can( $accessor ) );
        $framework->$accessor( $args->{ $accessor } );
    }

    return $framework->pre_order;
}

=head2 create_pre_order_with_exportable_items

=cut

sub create_pre_order_with_exportable_items {
    my $self = shift;

    my $framework = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );

    $framework->pre_order_status($PRE_ORDER_STATUS__COMPLETE);
    $framework->pre_order_item_status($PRE_ORDER_ITEM_STATUS__COMPLETE);

    $framework->reservation_status($RESERVATION_STATUS__UPLOADED);

    return $framework->pre_order;
}


=head2 create_two_pre_orders_for_last_ordered_variant

=cut

sub create_two_pre_orders_for_last_ordered_variant {
    my ($self) = @_;

    my $cloned_products;

    my $framework = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );

    $framework->create_reservations(0);
    $framework->product_quantity(1);
    $framework->variant_order_quantity(1);
    $framework->create_payment(0);
    $framework->pre_order_status($PRE_ORDER_STATUS__INCOMPLETE);
    $framework->pre_order_item_status($PRE_ORDER_ITEM_STATUS__SELECTED);

    $cloned_products = $framework->products;
    my $first_pre_order = $framework->pre_order;

    $framework = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );

    $framework->create_reservations(0);
    $framework->create_payment(0);
    $framework->pre_order_status($PRE_ORDER_STATUS__INCOMPLETE);
    $framework->pre_order_item_status($PRE_ORDER_ITEM_STATUS__SELECTED);
    $framework->products($cloned_products);

    my $second_pre_order = $framework->pre_order;

    return ($first_pre_order, $second_pre_order);
}


=head2 create_pre_order_reservations

    my $array_ref   = __PACKAGE__->create_pre_order_reservations( {
                                                                products    => [ Public::Product objects ],     # optional
                                                                variants    => [ Public::Variant objects ],     # optional
                                                            } );

Will create a 'Complete' Pre-Order using 'Test::XT::Data::PreOrder' and
then return an Array Ref of all of its Reservations.

If you need to alter stuff for the Pre-Order such as Channel or use
a particular Customer, then please pass arguments to this method and
change the code to use them accordingly, just make sure it still does
the expected thing when passed with NO arguments.

=cut

sub create_pre_order_reservations {
    my $self    = shift;
    my $args    = shift;

    my $framework   = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );

    ARGS:
    foreach my $accessor ( keys %{ $args } ) {
        next ARGS       if ( !$framework->can( $accessor ) );
        $framework->$accessor( $args->{ $accessor } );
    }

    return $framework->reservations;
}

=head2 create_pre_order_for_variants

  $pre_ord_obj    = __PACKAGE__->create_create_pre_order_for_variants();

Will create a 'Complete' Pre-Order using 'Test::XT::Data::PreOrder' for
given variants.

If variants are not provided it works exactly same as method create_complete_pre_order

=cut

sub create_pre_order_for_variants {
    my $self     = shift;
    my $variants = shift;

    my $framework   = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );

    $framework->variants($variants) if $variants;

    return $framework->pre_order;
}

=head2 create_refund_for_pre_order

    my $pre_order_refund_obj    = __PACKAGE__->create_refund_for_pre_order( $pre_order_obj, $number_of_items_to_refund );

This will Create a Pending Pre-Order Refund for the number of items specfied. It will
refund available to be refunded items in 'pre_order_item.id' order.

=cut

sub create_refund_for_pre_order {
    my ( $self, $pre_order, $num_of_items )     = @_;

    my $pre_order_refund    = $pre_order->create_related( 'pre_order_refunds', {
                                                                    pre_order_refund_status_id  => $PRE_ORDER_REFUND_STATUS__PENDING,
                                                            } );

    my @items   = $pre_order->pre_order_items->available_to_cancel->order_by_id->all;
    my $count   = 0;
    ITEM:
    foreach my $item ( @items ) {
        $count++;

        $pre_order_refund->create_related( 'pre_order_refund_items', {
                                                        pre_order_item_id   => $item->id,
                                                        unit_price          => $item->unit_price,
                                                        tax                 => $item->tax,
                                                        duty                => $item->duty,
                                                } );

        last ITEM       if ( $count >= $num_of_items );
    }

    return $pre_order_refund;
}

=head set_pre_order_active_state_for_channel

    $previous_state = __PACKAGE__->set_pre_order_active_state_for_channel( $channel_obj, 1 or 0 );

Will set the Active State for a Sales Channel for the Pre-Order functionality. Returns the previous
state it was set to.

=cut

sub set_pre_order_active_state_for_channel {
    my ( $self, $channel, $state )  = @_;

    my $current_state   = $channel->is_pre_order_active;

    my $group           = $channel->config_groups->search( { name => 'PreOrder' } )->first;
    my $setting         = $group->config_group_settings->search( { setting => 'is_active' } )->first;
    $setting->update( { value => $state } );

    return $current_state;
}

=head2 create_complete_pre_order_for_channel

    $pre_ord_obj    = __PACKAGE__->create_complete_pre_order_for_channel($channel_dbix_object);

Will create a 'Complete' Pre-Order using 'Test::XT::Data::PreOrder' for a specific channel.

=cut

sub create_complete_pre_order_for_channel {
    my ($self, $channel)    = @_;

    my $framework   = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::PreOrder',
        ],
    );

    $framework->channel($channel);

    return $framework->pre_order;
}

=head2 create_order_linked_to_pre_order

    $orders_obj     = __PACKAGE__->create_order_linked_to_pre_order( { # optional args hash ref
                                                                    order_item_counts => [ ... ],
                                                            } );

This will create a Pre-Order, one or more Orders, link them all together and
return the Orders DBIC object(s) and the Pre-Order object.

The C<order_item_counts> argument should be an ArrayRef of integers,
indicating how many Orders should be created ad how many items for each Order.

This will create a single Order with two Items:

    order_item_counts => [ 2 ]

This will create two orders, each with two items:

    order_item_counts => [ 2, 2 ]

This will create two orders, the first with two items and the second with
three items:

    order_item_counts => [ 2, 3 ]

=cut

sub create_order_linked_to_pre_order {
    my ( $self, $args )     = @_;

    my ( $pre_order, @orders ) = $self->create_part_exported_pre_order($args);

    return @orders == 1
        ? $orders[0]
        : @orders;

}

sub create_part_exported_pre_order {
    my ( $self, $args )     = @_;

    my $framework   = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Order',
            'Test::XT::Data::Channel',
            'Test::XT::Data::PreOrder',
        ],
    );

    my @order_item_counts = exists $args->{order_item_counts} && ref( $args->{order_item_counts} ) eq 'ARRAY'
        ? @{ $args->{order_item_counts} }
        : ( $framework->product_quantity );

    # Create two more items for the Pre-Order than the total sum requested,
    # so we can make it Part-Exported.
    my $num_pids_for_order      = sum( @order_item_counts );
    my $num_pids_for_preorder   = $num_pids_for_order + 2;
    my ( $channel, $pids )      = Test::XTracker::Data->grab_products( {
                                                        channel         => $args->{channel} // $framework->channel,
                                                        how_many        => $num_pids_for_preorder,
                                                        ensure_stock_all_variants => 1,
                                                    } );

    $framework->channel( $channel );

    # first create a Pre-Order
    my @order_pids  = splice( @$pids, 0, $num_pids_for_order );
    my @all_pids    = ( @order_pids, @$pids );
    my $pre_order   = $self->create_complete_pre_order( {
                                                    channel     => $channel,
                                                    variants    => [ map { $_->{variant} } @all_pids ],
                                                    product_quantity    => $num_pids_for_preorder,
                                                    ( $args->{customer} ? ( customer => $args->{customer} ) : () ),
                                                    ( $args->{pre_order_args} ? %{ $args->{pre_order_args} } : () ),
                                                } );

    my @orders;
    my $pre_order_count = 0;

    foreach my $order_item_count ( @order_item_counts ) {

        # now create an Order using the requested number of items for this Order.
        my $pids_for_order  = [ splice( @order_pids, 0, $order_item_count ) ];
        my $order_details   = $framework->new_order(
                                    channel     => $pre_order->channel,
                                    products    => $pids_for_order,
                                    address     => $pre_order->shipment_address,
                                    tenders     => [ { type => 'card_debit', value => $pre_order->total_value } ],
                                );
        my $order   = $order_details->{order_object};
        my $shipment= $order_details->{shipment_object};

        # do a few things to make it the same as for the Pre-Order
        $order->update( { customer_id => $pre_order->customer_id } );
        my $pre_ord_payment = $pre_order->get_payment;
        $order->payments->delete;
        Test::XTracker::Data->create_payment_for_order( $order, {
            psp_ref     => $pre_ord_payment->psp_ref,
            preauth_ref => $pre_ord_payment->preauth_ref,
            settle_ref  => $pre_ord_payment->settle_ref,
            fulfilled   => 1,
        } );
        $shipment->update( { shipping_charge => 0 } );      # Pre-Order's have ZERO Shipping Cost

        # update Statuses for the Pre-Order
        my @pre_order_items = $pre_order->pre_order_items->search( {
                                                            variant_id => { 'in' => [ map { $_->{variant_id} } @{ $pids_for_order } ] },
                                                        } )->all;
        foreach my $item ( @pre_order_items ) {
            $item->update_status( $PRE_ORDER_ITEM_STATUS__EXPORTED );
            $item->reservation->update( { status_id => $RESERVATION_STATUS__PURCHASED } );
            my $ship_item   = $shipment->shipment_items->search( { variant_id => $item->variant_id } )->first;
            $item->reservation->create_related('link_shipment_item__reservations', {
                                                            shipment_item_id => $ship_item->id,
                                                        } );
        }

        # link it to the Pre-Order
        $order->link_with_preorder( $pre_order->pre_order_number );

        $pre_order_count += scalar( @pre_order_items );
        push @orders, $order->discard_changes;

    }

    $pre_order->update_status( (
                                $pre_order->pre_order_items->count == $pre_order_count
                                ? $PRE_ORDER_STATUS__EXPORTED
                                : $PRE_ORDER_STATUS__PART_EXPORTED
                            ) );

    return ( $pre_order->discard_changes, @orders );

}

=head2 create_part_exported_pre_order_with_a_missing_order

=cut

sub create_part_exported_pre_order_with_a_missing_order {
    my $self = shift;

    my ($pre_order, $order) = $self->create_part_exported_pre_order();

    $pre_order->pre_order_items->search({
        pre_order_item_status_id => $PRE_ORDER_ITEM_STATUS__EXPORTED
    })->first->reservation->link_shipment_item__reservations->delete();

    return $pre_order->discard_changes;
}

=head2 create_pre_orderable_products

    $array_ref = __PACKAGE__->create_pre_orderable_products( {
        num_products             => 2,
        num_variants_per_product => 5,
        amount_of_stock_to_order => 100,
    } );

Returns an Array Ref. of Products that are Pre-Orderable. Pass in the Number
of Products that are required and the number of Variants per Product to be
created, the default will be 5 & 3 respectively. Also specify how many items
of Stock per Variant should be on the 'Stock Order', defaults to 10.

=cut

sub create_pre_orderable_products {
    my ( $self, $args ) = @_;

    my $framework   = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::PreOrder',
        ],
    );
    $framework->product_quantity( $args->{num_products} )
                                            if ( $args->{num_products} );
    $framework->variants_per_product( $args->{num_variants_per_product} )
                                            if ( $args->{num_variants_per_product} );
    $framework->variant_order_quantity( $args->{amount_of_stock_to_order} )
                                            if ( $args->{amount_of_stock_to_order} );

    my $products = $framework->products;
    # make sure each Product is not yet 'Live'
    foreach my $product ( @{ $products } ) {
        $product->discard_changes->product_channel->update( { live => 0 } );
    }

    return $products;
}

1;
