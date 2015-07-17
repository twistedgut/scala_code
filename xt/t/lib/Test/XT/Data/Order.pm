package Test::XT::Data::Order;

use NAP::policy qw( role test );

=head1 Test::XT::Data::Order

A Role to be loaded as a trait with either 'Test::XT::Data' or 'Test::XT::Flow' to create Customer Orders.

=cut

#
# Location data for the Test Framework
#

use Test::XTracker::Data;

use XT::Domain::PRLs;
use XTracker::Config::Local 'config_var';
use XTracker::Constants         qw( :application );
use XTracker::Constants::FromDB qw(
    :allocation_item_status
    :allocation_status
    :shipment_item_status
    :shipment_status
    :shipment_type
);
use XTracker::AllocateManager;
use NAP::DC::Barcode;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;

use Test::XT::Data::Container;

=head1 ATTRIBUTES

=head2 order

Called on its own will create an Order for a Sales Channel, requires a 'channel' attribute to be set to the desired Sales Channel,
this can be got (amongst other ways) by also specifying the 'Test::XT::Data::Channel' trait.

This attribute will also hold the DBIC Order object that the following methods create:

    new_order
    selected_order
    picked_order
    packed_order

If you create orders using the above methods then the trait 'Test::XT::Data::Channel' doesn't need to be loaded.

=cut

has order => (
    is          => 'rw',
    lazy        => 1,
    builder     => '_set_order',
);

############################
# Attribute default builders
############################

sub _set_order {
    my ($self) = @_;

    note "Calling grab_products for: " . $self->channel->web_name;
    my ($channel, $pids) = Test::XTracker::Data->grab_products({
        channel => $self->channel->web_name,
        dont_ensure_stock => 1,
        how_many_variants => 2, # useful if things are going to create exchanges later
    });
    note "Got channel [".$channel->id."] and pid: [" . $pids->[0]->{'sku'} . ']';

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => 'DHL Express' } );
    note "Got shipping account [".$ship_account->id."]";

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $self->channel->id } );
    note "Got customer [".$customer->id."]";

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $self->channel->id );
    note "Did ensure stock";

    my $address = Test::XTracker::Data->order_address( {
        address     => 'create',
        towncity    => 'London',
        county      => '',
        country     => 'United Kingdom',
        postcode    => 'NW10 4GR',
    });

    my $base = {
        customer_id             => $customer->id,
        channel_id              => $self->channel->id,
        shipment_type           => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status         => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id     => $ship_account->id,
        invoice_address_id      => $address->id,
        shipping_charge_id      => 4   # UK Express
    };

    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        base    => $base,
        pids    => $pids,
        attrs   => [
            { price => 100.00 },
        ],
    });
    note "Called create db order";

    my $order_nr = $order->order_nr;
    note "created Order ID: ".$order->id;
    note "Order number: $order_nr";
    return $order;
}

=head1 METHODS

All of the following '*_order' methods will create a Customer Order and place the DBIC Order object into '$self->order' and return
a hash ref containing the following:

    {
        order_object            => $order,
        product_objects         => $pids,
        channel_object          => $channel,
        customer_object         => $customer,
        shipping_account_object => $ship_account,
        address_object          => $address,
        shipment_object         => $order->shipments,
        shipment_id             => $order->shipments->first->id
    }

=head2 new_order

Creates an order with C<products> products, all from the same channel, and all
with guaranteed stock. Customer is selected, with enough store-credit to
purchase the items and skip the PSP.

=cut

sub new_order {
    my ( $self, %args ) = @_;
    my %grab_products_options;

    my ( $channel, $pids );

    if (ref($args{products}) eq 'ARRAY') {
        note "Using passed-in products and channel, skipping grab_products";
        $pids = $args{products};

        # Map from DBIc::Rows to Test::XTracker::Data fancy-pants idiocy
        unless ( exists $pids->[0]->{'sku'} ) {
            $pids = [ map {
                Test::XTracker::Data->explode_dbic_product_row_like_find_products_does(
                    $_
                )} @$pids ];
        }

        $channel = $args{channel} // $pids->[0]->{'product_channel'}->channel;
    }
    else {
        $grab_products_options{'how_many'} = $args{'products'} || 1;
        $grab_products_options{'how_many_variants'} = $args{'how_many_variants'} || 2;
        $grab_products_options{'ensure_stock_all_variants'} = $args{'ensure_stock_all_variants'} || 0;
        note "Selecting $grab_products_options{'how_many'} products ".
            "with at least $grab_products_options{'how_many_variants'} variants";

        if ( $args{'channel'} ) {
            note "Enforcing products come from channel $args{'channel'}";
            $grab_products_options{'channel'}  = $args{'channel'};
        }

        ( $channel, $pids ) = Test::XTracker::Data->grab_products({
            force_create => 1, %grab_products_options
        });
    }

    note "Shipment:";
    note "\tChannel: [" . $channel->name . ']';
    note "\tProduct: SKU: [" . $_->{'sku'} . '] Variant ID: [' .
        $_->{'variant_id'} . ']' for @$pids;

    my $ship_account =
        Test::XTracker::Data->find_or_create_shipping_account( {
            carrier    => $args{carrier} || config_var('DistributionCentre','default_carrier'),
            channel_id => $channel->id
        } );
    note 'Shipping account: [' . $ship_account->id . ']';

    my $address = $args{address}
        || Test::XTracker::Data->create_order_address_in("current_dc_premier");

    my $customer = $args{customer} //
                Test::XTracker::Data->find_customer( { channel_id => $channel->id } );
    note 'Customer: [' . $customer->id . ']';

    unless ( $args{'no_ensure'} ) {
        Test::XTracker::Data->ensure_stock(
            $_->{'pid'}, $_->{'size_id'}, $channel->id ) for @$pids;
    }

    my $shipment_type;
    if ($args{'premier'}) {
        # old way of doing it
        diag(__PACKAGE__.'::new_order( premier => ... ) is deprecated.'
            .' Please use ( shipment_type => ... ) instead');
        $shipment_type = $args{'premier'}
            ? $SHIPMENT_TYPE__PREMIER
            : $SHIPMENT_TYPE__DOMESTIC;
    }
    else {
        # more flexible way
        $shipment_type = $args{shipment_type} || $SHIPMENT_TYPE__DOMESTIC;
    }

    my $base = {
        customer_id          => $customer->id,
        channel_id           => $channel->id,
        shipment_type        => $shipment_type,
        shipment_status      => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id  => $ship_account->id,
        invoice_address_id   => $address->id,
        tenders              => delete $args{tenders},
        create_renumerations => $args{create_renumerations},
        date                 => delete $args{order_date},
    };

    note "Creating order";
    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => $base,
        attrs => [
            { price => 100.00 },
        ],
    });
    note 'Order [' . $order->id . '] created';

    if ($args{'gift_message'}) {
        $order->shipments->first->update({'gift_message'=>$args{'gift_message'}});
    }

    # set the Order attribute
    $self->order( $order->discard_changes );

    $self->allocate_to_shipment( $order->shipments->first(), $args{'prl_id'} )
        unless $args{'dont_allocate'};

    # Copy the artifact objects in to the Flow object for later perusal
    return {
        order_object            => $order,
        product_objects         => $pids,
        channel_object          => $channel,
        customer_object         => $customer,
        shipping_account_object => $ship_account,
        address_object          => $address,
        shipment_object         => $order->shipments,
        shipment_id             => $order->shipments->first->id
    };
}

=head2 allocate_to_shipment

Will pretend we recieved a successful allocate response for each allocation in the given shipment

=cut

sub allocate_to_shipment {
    my ($self, $shipment, $prl_id) = @_;

    my $prl_row;
    if ( $prl_id ) {
        $prl_row = $self->schema->resultset("Public::Prl")->find($prl_id);
    }

    # Allocate the shipment (won't do or return anything unless PRLs are turned on)
    my @allocations = $shipment->allocate({
        operator_id => $APPLICATION_OPERATOR_ID
    });

    # Then pretend there was a successful allocate response for each allocation
    foreach my $allocation (@allocations) {
        if ( $prl_row ) {
            note "Hard coding PRL to [" . $prl_row->name . "]";
            $allocation->update({ prl_id => $prl_row->id });
        }

        my @allocation_items = $allocation->allocation_items;
        my $sku_data;
        foreach my $allocation_item (@allocation_items) {
            my $sku = $allocation_item->variant_or_voucher_variant->sku;
            $sku_data->{$sku}->{allocated}++;
            $sku_data->{$sku}->{short} = 0;
        }
        XTracker::AllocateManager->allocate_response({
            allocation       => $allocation,
            allocation_items => \@allocation_items,
            sku_data         => $sku_data,
            operator_id      => $APPLICATION_OPERATOR_ID
        });
    }
}

=head2 selected_order

Does precisely the same as 'new_order' method, accepting the same arguments.
The single difference is that it will leave the shipment in the 'selected' state

=cut

sub selected_order {
    my ( $self, %args ) = @_;
    my $order_data = $self->new_order(%args);
    my $shipment = $order_data->{shipment_object};
    my $shipment_items = $shipment->shipment_items;

    my $operator = $self->schema->resultset('Public::Operator')
        ->get_operator_by_username( ( $self->can('mech') ? $self->mech->logged_in_as : '' ) );

    while (my $item = $shipment_items->next){
        $item->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED});
        # Also create the logs otherwise it won't be a proper shipment.
        $item->create_related( 'shipment_item_status_logs', {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED,
            operator_id => ($operator ? $operator->id : $APPLICATION_OPERATOR_ID ),
        } );

    }
    $shipment_items->reset; #reset the index

    # update the Order attribute
    $self->order->discard_changes;

    # Update allocations
    my @allocations = $shipment->allocations;
    $_->update({ status_id => $ALLOCATION_STATUS__PICKING }) for @allocations;
    # and their items
    foreach my $alloc (@allocations) {
        foreach my $ai ($alloc->allocation_items) {
            $ai->update_status($ALLOCATION_ITEM_STATUS__PICKING, $APPLICATION_OPERATOR_ID);
        }
    }

    return $order_data;
}

=head2 picked_order

Does precisely the same as 'selected_order' method, accepting the same
arguments, except it also picks the items into a new tote for you and leaves
the items in a 'picked' state and returns the tote id it picked into in the
returned data hash. It accepts a C<with_staged_allocations> option which sets
any allocations that have a post-picking-staging-area to I<Staged>.

=cut

sub picked_order {
    my ( $self, %args ) = @_;

    my $with_staged_allocations = delete $args{with_staged_allocations};
    my $multi_tote = delete $args{multi};

    my $order_data = $self->selected_order(%args);
    my $shipment        = $order_data->{'shipment_object'};
    my $shipment_items  = $order_data->{'shipment_object'}->shipment_items;
    my $shipment_id     = $order_data->{'shipment_id'};
    my $order_id        = $order_data->{'order_object'}->id;

    # Knock up a tote
    my $tote_id;
    $tote_id = NAP::DC::Barcode->new_from_id($args{tote_id}) if $args{tote_id};

    # If we have PRLs we have allocations, otherwise we don't. Either way,
    # shipment_items need to be picked...
    if ( config_var(qw/PRL rollout_phase/) ) {
        # Pretend we got the pick_complete message and make sure everything is
        # in its correct state
        for my $allocation ($shipment->allocations->all) {
            $tote_id = $self->_get_new_tote_id() if $multi_tote || !$tote_id;
            note "Picking allocation " . $allocation->id
                . " from shipment $shipment_id from order $order_id into tote $tote_id";
            $self->pick_allocation(
                $allocation, { tote_id => $tote_id, to_staged => $with_staged_allocations }
            );
        }

    }
    else {
        for my $shipment_item ($shipment->shipment_items->all) {
            $tote_id = $self->_get_new_tote_id() if $multi_tote || !$tote_id;
            note "Picking shipment item " . $shipment_item->id
                . " from shipment $shipment_id from order $order_id into tote $tote_id";
            $shipment_item->pick_into( $tote_id, $APPLICATION_OPERATOR_ID )
        }
    }

    # update the Order attribute
    $self->order->discard_changes;

    return {%$order_data,
            tote_id => $tote_id};
}

sub _get_new_tote_id {
    my ($self, $args) = @_;
    my $tote_id = Test::XT::Data::Container->get_unique_id;
    return NAP::DC::Barcode->new_from_id($tote_id); # Ensure it's a Barcode object
}

=head2 pick_allocation( $allocation, [\%args] ) : $allocation

Pick the given allocation. This method takes an optional hashref accepting the
following keys:

=over

=item tote_id => $tote_id

Creates one on the fly if you don't pass a value here.

=item to_staged => Bool

Defaults to false. Sets any allocations that have a
post-picking-staging-area to I<Staged>.

=back

=cut

sub pick_allocation {
    my ( $self, $allocation, $args ) = @_;

    my $tote_id = $args->{tote_id} // NAP::DC::Barcode->new_from_id(
        Test::XT::Data::Container->get_unique_id(),
    );
    # Set a flag if we want staged items and the PRL supports them
    my $to_staged = $args->{to_staged} && $allocation->prl->has_staging_area;

    $allocation->update({ status_id =>
        $to_staged ? $ALLOCATION_STATUS__STAGED : $ALLOCATION_STATUS__PICKED
    });
    my $allocation_items = $allocation->allocation_items;
    # Pick allocation items...
    $allocation_items->update({
        status_id => $ALLOCATION_ITEM_STATUS__PICKED,
        picked_into => $tote_id,
        picked_at => $self->schema->db_now,
        picked_by => $APPLICATION_OPERATOR_ID,
    });
    # ... and shipment items into the tote
    $_->pick_into( $tote_id, $APPLICATION_OPERATOR_ID )
        for $allocation_items->related_resultset('shipment_item')->all;

    return $allocation;
}

=head2 packed_order

Does precisely the same as 'picked_order' method, accepting the same arguments,
except it also packs the items into a box and leaves the items in a 'packed' state
and returns the box id it picked into in the returned data hash

=cut

sub packed_order {
    my ( $self, %args ) = @_;

    # NOTE: Calling picked_order here sets picked_* cols for the allocation
    # item - if we decide to clear these (specifically picked_into) for the
    # pick manager to be more accurate, then we will need to update this method
    my $order_data = $self->picked_order(%args);
    my $shipment        = $order_data->{'shipment_object'};
    my $shipment_id     = $shipment->id;
    my $shipment_items  = $shipment->shipment_items;
    my $order_id        = $order_data->{'order_object'}->id;

    # pack it in!
    my $box_ids = Test::XTracker::Data->get_inner_outer_box( $order_data->{channel_object}->id );
    $box_ids->{'shipment_box'} = Test::XTracker::Data->get_next_shipment_box_id;
    note "Packing shipment $shipment_id from order $order_id into box with id " . $box_ids->{'shipment_box'};
    my $shipment_box = $shipment->add_to_shipment_boxes(
                    {id            => $box_ids->{'shipment_box'},
                     shipment_id   => $shipment_id,
                     box_id        => $box_ids->{outer_box_id},
                     inner_box_id  => $box_ids->{inner_box_id},
                     hide_from_iws => 1,
                    });
    while (my $si = $shipment_items->next){
        $si->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED,
                     shipment_box_id         => $shipment_box->id});
    }

    # update the Order attribute
    $self->order->discard_changes;

    return {%$order_data,
            %$box_ids };
}

=head2 dispatched_order

Packs an order and then dispatches it. Takes the same arguments as the other *_order
methods.

=cut

sub dispatched_order {
    my ( $self, %args ) = @_;

    my $order_data = $self->packed_order(%args);
    my $shipment        = $order_data->{'shipment_object'};
    my $shipment_id     = $shipment->id;
    my $shipment_items  = $shipment->shipment_items;
    my $order_id        = $order_data->{'order_object'}->id;

    note "Dispatching shipment $shipment_id from order $order_id";
    # We do have a $shipment->dispatch method, but it has a lot of checks -
    # just set everything to dispatched manually and log
    $shipment->update({ 'shipment_status_id' => $SHIPMENT_STATUS__DISPATCHED, });
    $shipment->create_related('shipment_status_logs', {
        shipment_status_id => $SHIPMENT_STATUS__DISPATCHED,
        operator_id => $APPLICATION_OPERATOR_ID,
    });
    while (my $si = $shipment_items->next){
        $si->update({shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED});
        $si->create_related('shipment_item_status_logs', {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED,
            operator_id => $APPLICATION_OPERATOR_ID,
        });
    }

    # update the Order attribute
    $self->order->discard_changes;

    return {%$order_data};
}


1;
