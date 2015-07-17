package Test::XT::Flow::Fulfilment; ## no critic(ProhibitExcessMainComplexity)

use NAP::policy "tt", qw( test role );

use Test::XTracker::Data;
use Test::XTracker::PrintDocs;
use Carp qw/croak/;

requires 'mech';
requires 'note_status';

use XTracker::Config::Local qw(
    config_var
    putaway_intransit_type
);
use XTracker::Config::Parameters 'sys_param';
use XTracker::Constants   qw( :application );
use XTracker::Constants::FromDB
    qw( :shipment_status :shipment_type :shipment_item_status );
use XTracker::Database::Distribution    qw( AWBs_are_present );
use XTracker::Database::Shipment        qw( :DEFAULT );

use XTracker::Database::Distribution    qw( AWBs_are_present );
use XTracker::Database::Shipment    qw( get_shipment_info );

use Test::XT::Data::Container;
use Test::XT::Fulfilment::Putaway;

use Test::Config;

with
    'Test::XT::Flow::AutoMethods',
    'Test::XT::Data::Order',
    'Test::XT::Flow::WMS',
    'Test::XT::Flow::PRL',
    'XTracker::Role::WithAMQMessageFactory';

=head1 PROCESS OVERVIEW

Once an order has been accepted, it turns up on the Selection page.

    # Retrieve the Selection page
    $framework->flow_mech__fulfilment__selection

 At the DC, someone chooses which orders to 'select' for fulfilment.

    # Select a shipment
    my $picking_list = $framework->flow_mech__fulfilment__selection_submit(
        $shipment_id
    );

This prints out a picking sheet. A picker scans the shipment ID on the Picking
page to start the Picking process.

    $framework->flow_mech__fulfilment__picking();
    $framework->flow_mech__fulfilment__picking_submit( $shipment_id );

He then works through the items on the Picking sheet, scanning in their Location
and SKU.

    for my $item (@{ $picking_list->{'item_list'} }) {
        my $location = $item->{'Location'};
        my $sku      = $item->{'SKU'};

        $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $location );
        $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );
    }

Once every item is picked, the box is transported to the packing area. A packer
receives the box, and the picking sheet, and scans in the shipment id.

    $framework->flow_mech__fulfilment__packing();
    $framework->flow_mech__fulfilment__packing_submit( $shipment_id );

It's also possible (and more common) to scan a tote:

    $framework->flow_mech__fulfilment__packing_submit( $container_id );

If the tote contains a single shipment, it is selected and the packer
can carry on. If the tote contains more than one shipment, the packer
is kept on the packing list page, and asked to scan an item from the
tote, to find out which shipment to pack:

    $framework->flow_mech__fulfilment__packing_submit( $sku );

This is now enough to select the shipment. NOTE: if two or more
shipments in the same tote have the same SKU (i.e. there are two or
more identical items in the tote), we just pick one shipment, since
the items are interchangeable.

If there are any physical vouchers in the shipment, the packer will
need to QC Voucher by scanning the Voucher Code on each physical
Voucher and then Continue to the Packing screen.

Having QC'd the items, they click the "Start Packing" button, which bills the
customer.

    $framework->flow_mech__fulfilment__packing_checkshipment_submit();

They go through each item, scanning it as they pack it.

    for my $item (@{ $picking_list->{'item_list'} }) {
        my $sku      = $item->{'SKU'};
        $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );
    }

Once every item is packed, they'll be asked about the boxes they used - which
inner-box they used, and which unique-identifier-barcode (with box-type
embedded) they put on the outer box.

    $framework->flow_mech__fulfilment__packing_packshipment_submit_boxes(
        inner => 7, outer => 17
    );

Then the Airway Bill.

    $framework->flow_mech__fulfilment__packing_packshipment_submit_waybill(
        "0123456789"
    );

Finally they mark the packing as complete.

    $framework->flow_mech__fulfilment__packing_packshipment_complete();

=head1 METHODS

=head2 flow_db__fulfilment__create_order

Creates an order with C<products> products, all from the same channel, and all
with guaranteed stock. Customer is selected, with enough store-credit to
purchase the items and skip the PSP.


This is a wrapper for the method 'Test::XT::Data::Order->new_order';

=over

=item C<products>

=item C<channel>

=item C<carrier>

=item C<tenders>

=item C<gift_message>

=item C<address> - Default: address near the local DC

Invoice and shipment address.

=item C<create_renumerations> - Default: false

If true, create a renumeration for the shipment.

=back

Returns a hash-ref containing:

=over

=item C<order_object> - L<XTracker::Schema::Result::Public::Orders>

=item C<product_objects> - ArrayRef of product info hashes, that also contain a
link to the Variant row object. Worth Data::Dump'ing to know more.

=item C<channel_object> - L<XTracker::Schema::Result::Public::Channel>

=item C<customer_object> - L<XTracker::Schema::Result::Public::Customer>

=item C<shipping_account_object> - L<XTracker::Schema::Result::Public::ShippingAccount>

=item C<address_object> - L<XTracker::Schema::Result::Public::OrderAddress>

=item C<shipment_object> - L<XTracker::Schema::Result::Public::Shipment>

=item C<shipment_id> - ID of the shipment_object, for convenience

=back

=cut

sub flow_db__fulfilment__create_order {
    my $self    = shift;

    # 'new_order' is in 'Test::XT::Data::Order'
    return $self->new_order( @_ );
}

=head2 flow_mech__fulfilment__select_packing_station

Retrieves the Select Packing Station page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__select_packing_station',
    page_description => 'Select the packing station',
    page_url         => '/Fulfilment/Packing/SelectPackingStation'
);

=head2 flow_mech__fulfilment__select_packing_station_submit(channel_id => $channel_id)

=head2 flow_mech__fulfilment__select_packing_station_submit(packing_station => $packing_station_name)

Set the packing station to any valid value on the given channel, or specify a
packing station by name.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__select_packing_station_submit',
    form_name        => 'setPackingStation',
    form_description => 'set the packing station',
    assert_location  => qr{^/Fulfilment/Packing/SelectPackingStation},
    transform_fields => sub {
        my ( $self, %args ) = @_;

        my ( $channel_id, $packing_station )
            = @args{qw/channel_id packing_station/};

        croak 'You must pass a $channel_id or $packing_station but not both'
            unless $channel_id xor $packing_station;

        my $schema = $self->schema;
        # Get any packing station on the given channel_id
        if ( $channel_id ) {
            $packing_station = XTracker::Config::Local::get_packing_stations(
                $schema, $channel_id
            )->[0];
        }
        # Verify that the packing station exists
        elsif ( $packing_station ) {
            my @channel_ids
                = $schema->resultset('Public::Channel')->get_column('id')->all;
            my $packing_stations = XTracker::Config::Local::get_packing_stations(
                $schema, \@channel_ids
            );
            croak "The packing station you passed ($packing_station) cannot be found on any channel"
                unless grep { m{^$packing_station$} } @$packing_stations;
        }
        else {
            warn 'We should never get here...';
        }
        return { ps_name => $packing_station };
    }
);

=head2 flow_db__fulfilment__create_order_selected

Does precicely the same as flow_db__fulfilment__create_order method, accepting the same arguments.
The single difference is that it will leave the shipment in the 'selected' state


This is a wrapper for the method 'Test::XT::Data::Order->selected_order';

=cut

sub flow_db__fulfilment__create_order_selected {
    my $self    = shift;

    # 'selected_order' is in 'Test::XT::Data::Order'
    return $self->selected_order( @_ );
}


=head2 flow_db__fulfilment__create_order_picked

Does precicely the same as flow_db__fulfilment__create_order_selected method, accepting the same arguments,
except it also picks the items into a new tote for you and leaves the items in a 'picked' state
and returns the tote id it picked into in the returned data hash


This is a wrapper for the method 'Test::XT::Data::Order->picked_order';

=cut

sub flow_db__fulfilment__create_order_picked {
    my $self    = shift;

    # 'picked_order' is in 'Test::XT::Data::Order'
    return $self->picked_order( @_ );
}

=head2 flow_db__fulfilment__create_order_packed

Does precicely the same as flow_db__fulfilment__create_order_selected method, accepting the same arguments,
except it also packs the items into a box and leaves the items in a 'packed' state
and returns the box id it picked into in the returned data hash

This is a wrapper for the method 'Test::XT::Data::Order->packed_order';

=cut

sub flow_db__fulfilment__create_order_packed {
    my $self    = shift;

    # 'packed_order' is in 'Test::XT::Data::Order'
    return $self->packed_order( @_ );
}

=head2 flow_db__fulfilment__create_order_dispatched

Does precicely the same as flow_db__fulfilment__create_order_selected method, accepting the same arguments,
except it takes the shipment right through to dispatched status.

This is a wrapper for the method 'Test::XT::Data::Order->dispatched_order';

=cut

sub flow_db__fulfilment__create_order_dispatched {
    my $self = shift;

    return $self->dispatched_order( @_ );
}

=head2 flow_task__fulfilment__select_shipment_return_printdoc

Selects a shipment using C<flow_mech__fulfilment__selection_submit> and returns
the generated pick sheet's data. You must provide a shipment ID.

=cut

sub flow_task__fulfilment__select_shipment_return_printdoc {
    my ( $self, $shipment_number ) = @_;
    note "Our shipment is [$shipment_number]";

    note "Retrieving the shipment selection page";
    $self->flow_mech__fulfilment__selection;

    # Catch the printdocs
    note "Starting PrintDoc monitoring";
    my $print_folder = Test::XTracker::PrintDocs->new(strict_mode => 0);

    # Submit the selection
    note "Submitting the selection list";

    $self->flow_mech__fulfilment__selection_submit( $shipment_number );

    note "Looking for the picking sheet";
    my ($picking_sheet) = $print_folder->wait_for_new_files(files => 1);
    unless ( $picking_sheet ) {
        diag "No Picking Sheet found, and we were expecting one";
    }

    note "Picking sheet found";

    return $picking_sheet->as_data;
}

=head2 flow_mech__fulfilment__selection

Retrieves the Selection page

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__selection',
    page_description => 'Selection List',
    page_url         => '/Fulfilment/Selection'
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__selection_transfer',
    page_description => 'Selection List',
    page_url         => '/Fulfilment/Selection?selection=transfer'
);

=head2 flow_mech__fulfilment__selection_submit( $shipment_id, $operator_id = $APPLICATION_OPERATOR_ID ) : $flow

    $framework->flow_mech__fulfilment__selection_submit("Shipment ID");

Submits a single shipment ID for picking. You must provide the shipment ID.

=cut

__PACKAGE__->create_custom_method(
    method_name      => 'flow_mech__fulfilment__selection_submit',
    assert_location  => qr!^/Fulfilment/Selection!,
    handler          => sub {
        my $self = shift;
        my $shipment_id = shift;
        my $operator_id = shift // $APPLICATION_OPERATOR_ID;

        croak "You must provide a shipment id" unless $shipment_id;

        # In PRL mode we just send a pick message for allocations referencing
        # this shipment
        if ( config_var(qw/PRL rollout_phase/) ) {
            my $shipment = $self->schema->resultset('Public::Shipment')->find($shipment_id);
            $_->pick($self->msg_factory, $operator_id) for $shipment->allocations;
            return $self;
        }
        # if auto-selection is enabled, we can't use the form
        my $auto_select = sys_param('fulfilment/selection/enable_auto_selection');
        if ($auto_select) {
            # auto-selection - invoke the script code directly
            note "Auto-selecting shipment $shipment_id";
            my $auto_select_result = XTracker::Script::Shipment::AutoSelect->new->invoke(
                shipment_ids => [ $shipment_id ],
            );
            ok !$auto_select_result, "should auto-select shipment $shipment_id";
        }
        else {
            # manual selection - tick the appropriate box and submit the form
            my $form = $self->mech->form_name('f_select_shipment');
            $form->strict(0);
            $form->value( 'pick-' . $shipment_id => 1 );
            $self->mech->click_button( name => 'submit' );
            $self->note_status;
        }

        return $self;
    }
);

=head2 flow_mech__fulfilment__picking

Retrieves the Picking page

=head2 flow_mech__fulfilment__picking_submit

Submits a shipment id for picking. You must provide a shipment ID.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__picking',
    page_description => 'Picking Start Page',
    page_url         => '/Fulfilment/Picking',
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__picking_submit',
    scan_description => 'picking process',
    assert_location  => '/Fulfilment/Picking',
);

=head2 flow_mech__fulfilment__picking_pickshipment_submit_location

=head2 flow_mech__fulfilment__picking_pickshipment_submit_sku

Submits the Location and SKU for each of the products in the order. Location
must be scanned first. Both require a single string argument of the value you
want to use.

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__picking_pickshipment_submit_location',
    scan_description => 'picking location scan',
    assert_location  => qr!^/Fulfilment/Picking/PickShipment!
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__picking_pickshipment_submit_sku',
    scan_description => 'picking sku scan',
    assert_location  => qr!^/Fulfilment/Picking/PickShipment!
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__picking_pickshipment_submit_container',
    scan_description => 'picking container scan',
    assert_location  => qr!^/Fulfilment/Picking/PickShipment!
);

=head2 flow_mech__fulfilment__picking_incompletepick

Follows the 'Incomplete Pick' link button from a Picking page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__picking_incompletepick',
    link_description => 'Incomplete Pick',
    find_link        => { text => 'Incomplete Pick' },
    assert_location  => qr!^/Fulfilment/Picking/PickShipment!
);

=head2 flow_mech__fulfilment__packing

Retrieves the packing page

=head2 flow_mech__fulfilment__packing_submit

Submits a shipment id for packing.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__packing',
    page_description => 'packing Start Page',
    page_url         => '/Fulfilment/Packing'
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_submit',
    scan_description => 'packing process',
    assert_location  => qr!^/Fulfilment/Packing(\?|$)!
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_with_physical_vouchers_submit',
    scan_description => 'packing process with physical vouchers',
    assert_location  => qr!^/Fulfilment/Packing(\?|$)!
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_empty_tote',
    assert_location  => qr!^/Fulfilment/Packing\?.*?container_id=!,
    form_name        => 'emptyTote',
    form_description => 'mark the tote as empty',
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_accumulator__submit',
    scan_description => 'Scan extra tote or pigeonhole',
    assert_location  => qr!^/Fulfilment/Packing/Accumulator!
);

sub flow_task__fulfilment__packing_accumulator {
    my ( $self, @totes ) = @_;

    # Strip out the primary tote...
    my $primary_tote = $self->mech->as_data->{'primary_tote'};
    note "Primary tote: $primary_tote";
    @totes = grep { $primary_tote ne $_ } @totes;

    $self->flow_mech__fulfilment__packing_accumulator__submit( $_ )
        for @totes;
    return $self;
}

=head2 flow_mech__fulfilment__packing_scan_item

Scans an item for a multi-order tote

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_scan_item',
    scan_description => 'shipment selection via item scan',
    assert_location  => qr!^/Fulfilment/Packing\?container_id=!
);

=head2 flow_mech__fulfilment__packing_placeinpetote_scan_item

Scans an item on the PIPE page

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_placeinpetote_scan_item',
    scan_description => 'item on the pipe page',
    assert_location  => qr!^/Fulfilment/Packing/PlaceInPEtote!
);

=head2 flow_mech__fulfilment__packing_placeinpetote_scan_tote

Scans a tote on the PIPE page

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_placeinpetote_scan_tote',
    scan_description => 'tote on the pipe page',
    assert_location  => qr!^/Fulfilment/Packing/PlaceInPEtote!
);

=head2 flow_mech__fulfilment__packing_placeinpetote_pigeonhole_confirm

Confirms that a pigeonhole item has been returned to the same pigeonhole

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_placeinpetote_pigeonhole_confirm',
    assert_location  => qr!^/Fulfilment/Packing/PlaceInPEtote!,
    form_name        => 'pipe-item',
    form_description => 'confirm pigeonhole on PE',
);

=head2 flow_mech__fulfilment__packing_placeinpetote_mark_complete

Press the "Completed" button on PIPE page

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_placeinpetote_mark_complete',
    assert_location  => qr!^/Fulfilment/Packing/PlaceInPEtote!,
    form_name        => 'pipe-item',
    form_description => 'all items packed',
);

=head2 flow_mech__fulfilment__packing_emptytote_submit

Replies to the Yes/No question of are the totes emtpy

We pass a yes/no argument to this method.

 $framework->flow_mech__fulfilment__packing_emptytote_submit('yes');

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_emptytote_submit',
    assert_location  => qr!^/Fulfilment/Packing/EmptyTote!,
    form_name        => 'validate_empty_tote',
    form_description => 'confirm tote is empty',
    form_button      => sub {
        my $self = shift;
        my $reply = shift;

        if ( $reply eq 'yes' ) {
            return 'is_empty';
        } elsif ($reply eq 'no' ) {
            return 'not_empty';
        } else {
            croak "Please either pass in yes/no";
        }
    }
);


=head2 flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item

Scans an item on the PIPE-O page

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item',
    scan_description => 'item on the pipe-O page',
    assert_location  => qr!^/Fulfilment/Packing/PlaceInPEOrphan!
);

=head2 flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote

Scans a tote on the PIPE-O page

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote',
    scan_description => 'tote on the pipe-O page',
    assert_location  => qr!^/Fulfilment/Packing/PlaceInPEOrphan!
);

=head2 flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete

Press the "Completed" button on PIPE-O page

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete',
    assert_location  => qr!^/Fulfilment/Packing/PlaceInPEOrphan!,
    form_name        => 'pipeo-complete',
    form_description => 'all items packed',
);


=head2 flow_mech__fulfilment__packqc_voucher_code_submit

    $framework->flow_mech__fulfilment__packqc_voucher_code_submit($voucher_code)

Scan a voucher code and click Submit.

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packqc_voucher_code_submit',
    scan_description => 'Enter Voucher Code',
    assert_location  => qr!^/Fulfilment/Packing/PackQC(\?|$)!
);

=head2 flow_mech__fulfilment__packing_packqc_continue

    $framework->flow_mech__fulfilment__packing_packqc_continue;

Just clicks Continue in case the weird case we found of a canceled voucher asking for
the voucher code at Packing

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_packqc_continue',
    assert_location  => qr!^/Fulfilment/Packing/PackQC!,
    form_name        => 'QCPassed',
    form_description => 'Voucher QC',
    form_button      => 'submit'
);


=head2 flow_mech__fulfilment__packing_checkshipment_submit

Presses the button that confirms the packer has checked the items, and it's
ready to be packed. This takes payment as a consequence.

If you want to fail any items you should pass hash ref with the items you want
to fail and the reason. Items  are identified by their shipment_item_id - this
is preferable to SKU as SKUs can be repeated inside of an order. To do the
mapping, you can peek inside C<as_data> as in the example below. You can also
provide missing items as an arrayref.

e.g.

 my @items = @{$framework->mech->as_data()->{shipment_items}};

 my $fail_reason = 'Fail' . rand(100000000);

 $framework
    ->flow_mech__fulfilment__packing_checkshipment_submit(
    fail => {
        $items[0]->{'shipment_item_id'} => $fail_reason,
        $items[1]->{'shipment_item_id'} => $fail_reason
    },
    missing => [
        $items[2]->{'shipment_item_id'},
        $items[3]->{'shipment_item_id'}
    ]
 );

You /can/ also use SKU, but this has undefined behaviour if there's more than
one!

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packing_checkshipment_submit',
    form_name         => 'pickShipment',
    form_description  => 'packing qc',
    assert_location   => qr!^/Fulfilment/Packing/CheckShipment!,
    transform_fields  => sub {
        my ($self, %args) = @_;

        # Map SKUs to shipment_item_ids...
        my %skus;
        my %shipment_items;
        my $page_data = $self->mech->as_data();
        for ( @{ $page_data->{'shipment_items'} } ) {
            my $shipment_id = $_->{'shipment_item_id'} // '';
            my $sku = $_->{'SKU'};
            $shipment_items{ $shipment_id } = 1;
            $skus{$sku} = $shipment_id;
        }
        # not forgetting the extra items
        my %shipment_extra_items;
        for ( @{ $page_data->{'shipment_extra_items'} } ) {
            my $id = $_->{'id'};
            $shipment_extra_items{ $id } = 1;
        }

        # Start by marking them all as pass
        my %fields = map {; "shipment_item_qc_$_" => 1} keys %shipment_items;
        %fields = ( %fields, map {; "shipment_extra_item_qc_$_" => 1} keys %shipment_extra_items );

        # Look what the user asked us to fail, and fail it!
        foreach my $id (keys %{$args{fail}}) {
            my $shipment_item_id = $skus{$id} || ($shipment_items{$id} ? $id : undef);
            my $shipment_extra_item_id = $shipment_extra_items{$id} ? $id : undef;

            if ($shipment_item_id){
                $fields{"shipment_item_qc_$shipment_item_id"} = 0;
                $fields{"shipment_item_qc_${shipment_item_id}_reason"} =
                    $args{fail}->{$id};
            } elsif ($shipment_extra_item_id){
                $fields{"shipment_extra_item_qc_$shipment_extra_item_id"} = 0;
                $fields{"shipment_extra_item_qc_${shipment_extra_item_id}_reason"} =
                    $args{fail}->{$id};
            } else {
                croak "Can't find a match for [$id]";
            }
        }

        # Do the missing step
        for my $id (@{$args{missing}}) {
            my $shipment_item_id = $skus{$id} || ($shipment_items{$id} ? $id : undef);
            my $shipment_extra_item_id = $shipment_extra_items{$id} ? $id : undef;

            if ($shipment_item_id){
                $fields{"shipment_item_qc_$shipment_item_id"} = 2;
            } elsif ($shipment_extra_item_id){
                $fields{"shipment_extra_item_qc_$shipment_extra_item_id"} = 2;
            } else {
                croak "Can't find a match for [$id]";
            }
        }

        if ( $args{'printer'} ) {
            $fields{'packing_printer'} = $args{'printer'};
        }

        return \%fields;
    },
);

=head2 A note about packing exceptions

If one or more items failed then the shipment needs to be forwarded to a supervisor.
This method and the next handle the shipment supervisor's screen. If all passed, you
can jump straight forward to C<packing_packshipment_submit_sku>.

Otherwise, we now need to select the right shipment, scan that in, and then verify
it's been fixed, and then we can proceed as normal.

=head2 flow_mech__fulfilment__packingexception

Loads the list of packing exceptions to handle

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__packingexception',
    page_description => 'packing Exception Page',
    page_url         => '/Fulfilment/PackingException'
);

=head2 flow_mech__fulfilment__packingexception_submit

Submits a specific shipment ID to view in the packing exception screen

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packingexception_submit',
    scan_description => 'shipment id scan',
    assert_location  => qr!^/Fulfilment/PackingException!
);

=head2 flow_mech__fulfilment__packingexception_comment

From the packing exception screen, allows you to submit comments. Accepts a
single value: the comment text value.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packingexception_comment',
    form_name         => 'add_comments',
    form_description  => 'add comment',
    assert_location   => qr!^/Fulfilment/Packing/CheckShipmentException!,
    transform_fields  => sub {
        my $self = shift;
        my @user_arguments = @_;
        return { note_text => $user_arguments[0] }
    },
);

=head2 flow_mech__fulfilment__packingexception_edit_comment

Accepts a comment ID, and clicks the Edit Comment link based on it

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__packingexception_edit_comment',
    link_description => 'Edit Comment',
    assert_location  => qr!^/Fulfilment/Packing/CheckShipmentException!,
    transform_fields => sub {
        my $note_id = $_[1];
        return {
            url_regex => qr!^/Fulfilment/PackingException/Note.+note_id=$note_id!
        }
    }
);

=head2 flow_mech__fulfilment__packingexception_shipment_item_mark_faulty

=head2 flow_mech__fulfilment__packingexception_shipment_item_mark_missing

=head2 flow_mech__fulfilment__packingexception_shipment_item_mark_ok

=head2 flow_mech__fulfilment__packingexception_shipment_item_mark_quarantine

=head2 flow_mech__fulfilment__packingexception_shipment_item_mark_putaway

Push the corresponding button on the PE page

=cut

# Code that writes code that writes code. STAND BACK!
for my $action (qw( faulty missing ok quarantine putaway )) {

    __PACKAGE__->create_form_method(
        method_name      => 'flow_mech__fulfilment__packingexception_shipment_item_mark_' . $action,
        form_button      => $action eq 'ok' ? 'item_ok' : $action,
        form_name        => sub {
            my ( $self, $id ) = @_;

            # The ID /should/ be a shipment ID. If it's got a hyphen in it tho,
            # it's probably a PID, and we need to look that up.
            if ( $id =~ m/\-/ ) {
                my %sid_lookup = map {
                    my $shipment_item_id = $_->{'Shipment Item ID'};
                    if ( $shipment_item_id ) {
                        (
                            $_->{'SKU'} => $shipment_item_id
                        )
                    } else {
                        ();
                    }
                } @{ $self->mech->as_data()->{'shipment_items'} };

                my $shipment_item = $sid_lookup{ $id };
                croak "Can't find an item matching [$id]" unless $shipment_item;
                note "Mapped SKU $id to $shipment_item";
                $id = $shipment_item;
            }

            # First check for the multiplexer
            my $multiplexer = 'cancelled-pending-multiplexer-' . $id;
            if ( $self->mech->content =~ m/$multiplexer/ ) {
                return $multiplexer;
            }

            # If it's no there then 'ok' is on 'missing'
            if ( $action eq 'ok' ) {
                return 'missing-item-' . $id;

            # And everything else is the name of the form itself
            } else {
                return $action . '-item-' . $id;
            }
        },
        form_description => "submit $action item",
        assert_location  => qr!^/Fulfilment/Packing/CheckShipmentException!
    );

}

=head2 flow_mech__fulfilment__packingexception_shipment_extra_item_mark_ok

Press the "This item is OK! >>" button

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packingexception_shipment_extra_item_mark_ok',
    form_button      => 'extra_item_ok',
    form_name        => sub { 'extra-item-'.$_[1] },
    form_description => 'missing/faulty extra item OK',
    assert_location  => qr!^/Fulfilment/Packing/CheckShipmentException!,
    );

=head2 flow_mech__fulfilment__packingexception_delete_comment

Accepts a comment ID, and clicks the Edit Comment link based on it

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__packingexception_delete_comment',
    link_description => 'Delete Comment',
    assert_location  => qr!^/Fulfilment/Packing/CheckShipmentException!,
    transform_fields => sub {
        my $note_id = $_[1];
        return {
            url_regex => qr!^/Fulfilment/PackingException/EditNote.+note_id=$note_id!
        }
    }
);

=head2 flow_mech__fulfilment__packingexception__scan_item_into_tote

Accepts a SKU and scans item into shipment container

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packingexception__scan_item_into_tote',
    scan_description => 'scan found sku into exception tote',
    assert_location  => qr!^/Fulfilment/PackingException/ScanItemIntoTote!
);

=head2 flow_mech__fulfilment__packingexception__viewcontainer_remove_orphan

Accepts a SKU and removes orphan item from container

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packingexception__viewcontainer_remove_orphan',
    scan_description => 'scan orphan sku',
    assert_location  => qr!^/Fulfilment/PackingException/ViewContainer!
);

=head2 flow_mech__fulfilment__packingexception__viewcontainer_putaway_ready

Clicks the buttom "Mark as ready for putaway" on the PE view container page

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packingexception__viewcontainer_putaway_ready',
    assert_location   => qr!^/Fulfilment/PackingException/ViewContainer!,
    form_name         => 'send_to_putaway',
    form_description  => 'send to putaway',
);

=head2 flow_mech__fulfilment__packingexception_comment__submit

From the comment editing screen, allows you to submit comments. Accepts a
single value: the comment text value.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packingexception_comment__submit',
    form_name         => 'noteForm',
    form_description  => 'edit comments',
    assert_location   => qr!^/Fulfilment/PackingException/Note!,
    transform_fields  => sub {
        my $self = shift;
        my @user_arguments = @_;
        return { note_text => $user_arguments[0] }
    },
);

=head2 flow_mech__fulfilment__packing_checkshipmentexception_submit

Press the "Fix Shipment" button.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packing_checkshipmentexception_submit',
    form_name         => 'to_commissioner',
    form_description  => 'check shipment exception',
    assert_location   => qr!^/Fulfilment/Packing/CheckShipmentException!,
);

=head2 flow_mech__fulfilment__packingexception_scanoutpeitem__pigeonhole_confirm

Confirms that a pigeonhole item has been returned to the same pigeonhole from PE

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packingexception_scanoutpeitem__pigeonhole_confirm',
    assert_location  => qr!^/Fulfilment/PackingException/ScanOutPEItem!,
    form_name        => 'scan_faulty_items',
    form_description => 'confirm pigeonhole on PE',
);


=head2 flow_mech__fulfilment__packing_packshipment_submit_sku

Submits the SKU of the item you are currently packing. Accepts a string, which
will be used as the SKU.

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_packshipment_submit_sku',
    scan_description => 'picking sku scan',
    assert_location  => qr!^/Fulfilment/Packing/PackShipment!
);

=head2 flow_mech__fulfilment__packing_packshipment__assign_boxes

Prematurely press the 'assign boxes' button to assign boxes to items you've
already packed

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_packshipment__assign_boxes',
    assert_location  => qr!^/Fulfilment/Packing/PackShipment!,
    form_name        => 'boxShipment',
    form_description => 'assign boxes link',
);

=head2 flow_mech__fulfilment__packing_packshipment__submit_gift_card_code

Enter a Gift Card Code (same as Voucher Code) for the sku, and press the Submit button

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_packshipment__submit_gift_card_code',
    assert_location  => qr!^/Fulfilment/Packing/PackShipment$!,
    form_name        => 'packShipment',
    form_description => 'enter Gift Card Code',
    transform_fields  => sub {
        my $self = shift;
        my ($voucher_code) = @_;
        note "\tvoucher_code: [$voucher_code]";
        return { voucher_code => $voucher_code }
    },
);

=head2 flow_mech__fulfilment__packing_packshipment__pack_items

Takes you back to the pack items page if you've entered an intermediate box id.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__packing_packshipment__pack_items',
    assert_location  => qr!^/Fulfilment/Packing/PackShipment!,
    form_name        => 'packItems',
    form_description => 'pack items link',
);

=head2 flow_mech__fulfilment__packing_packshipment_submit_boxes

When packing is finished, you're confronted with box selection. A barcode
(or type) for outer, and a type for inner.
Submit channel_id to have an inner and outer box chosen for you
or alternatively you can pass your own {inner => '1',outer => '12312312312-50'} overrides

We might want to extend this to be able to be more selective about the boxes e.g. premier.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packing_packshipment_submit_boxes',
    form_name         => 'packShipment',
    form_description  => 'box allocations',
    assert_location   => qr!^/Fulfilment/Packing/PackShipment!,
    transform_fields  => sub {
        my ($self, %args) = @_;

        my $box_ids;
        unless (defined $args{'inner'} && defined $args{'outer'}) {

            if (defined $args{'channel_id'}) {
                $box_ids = Test::XTracker::Data->get_inner_outer_box( $args{'channel_id'} );
                $args{'inner'} = $box_ids->{inner_box_id};
                $args{'outer'} = $box_ids->{outer_box_id};
            } else {
                die "We need at least a channel_id";
            }

        }

        note "Setting the box types";
        note "\tInner: [" . $args{'inner'} . ']';
        note "\tOuter: [" . $args{'outer'} . ']';
        my $shipment_box_id = $args{'shipment_box_id'} ||
            Test::XTracker::Data->get_next_shipment_box_id;
        note "\tShipment Box ID: [" . $shipment_box_id . "]";

        return {
            enter_box     => 'yes',
            inner_box_id  => $args{'inner'},
            outer_box_id  => $args{'outer'},
            shipment_box_id => $shipment_box_id,
            ($args{'tote_id'} ? ( tote_id => $args{'tote_id'}->as_barcode ) : () ),
            ($args{'hide_from_iws'} ? ( hide_from_iws => $args{'hide_from_iws'} ) : () )
        };
    }
);

__PACKAGE__->create_form_method(
    method_name         => 'flow_mech__fulfilment__packing_packshipment_remove_box',
    form_name           => 'removeBox',
    form_description    => 'remove box link',
    assert_location     => qr!^/Fulfilment/Packing/PackShipment!,
    transform_fields    => sub {
        my ($self, %args) = @_;

        my %return_args;

        if (exists $args{shipment_box_id}) {
            $return_args{shipment_box_id} = $args{shipment_box_id};
        } else {
            die "We need a shipment_box_id";
        }

        note "Removing shipment box $return_args{shipment_box_id}";

        return \%return_args;
    }
);

=head2 flow_mech__fulfilment__packing_packshipment_submit_waybill

Sets the way-bill for the item. Several different formats are allowed, and
"0123456789" works fine. Accepts the code to use as the first argument.

If a shipment id has also been passed, it checks to see whether it already
has an associated AWB and does nothing if so (because the form field won't
be there).

=cut

__PACKAGE__->create_custom_method(
    method_name      => 'flow_mech__fulfilment__packing_packshipment_submit_waybill',
    assert_location  => qr!^/Fulfilment/Packing/PackShipment!,
    handler => sub {
        my ($self, $waybill, $shipment_id) = @_;
        if ($shipment_id) {
            my $shipment_info = get_shipment_info( $self->schema->storage->dbh, $shipment_id );
            if (AWBs_are_present { for => 'packing', on => $shipment_info }) {
                # Do nothing - the form won't be shown
                return $self;
            }
        }
        $self->indent_note("Scanning the AWB");
        $self->scan( $waybill );
        return $self;
    }
);

=head2 flow_mech__fulfilment__packing_packshipment_remove_waybill

Remove the return AWB from the shipment.

=cut

__PACKAGE__->create_form_method(
    method_name         => 'flow_mech__fulfilment__packing_packshipment_remove_waybill',
    form_name           => 'waybillForm',
    form_description    => 'Return Air Waybill',
    assert_location     => qr!^/Fulfilment/Packing/PackShipment!,
);

=head2 flow_mech__fulfilment__packing_packshipment_remove_item

Remove an item from a box

=cut

__PACKAGE__->create_form_method(
    method_name         => 'flow_mech__fulfilment__packing_packshipment_remove_item',
    form_name           => sub {
        my ($self, %args) = @_;
        return 'removeItem'.$args{shipment_item_id};
    },
    form_description    => 'Shipment Boxes Assigned',
    assert_location     => qr!^/Fulfilment/Packing/PackShipment!,
    transform_fields    => sub {
        my ($self, %args) = @_;
        if (!exists $args{shipment_item_id}) {
            die 'We need a shipment_item_id';
        }
        return \%args;
    },
);

=head2 flow_mech__fulfilment__packing_packshipment_add_waybill

Add a return AWB to a shipment.

=cut

__PACKAGE__->create_form_method(
    method_name         => 'flow_mech__fulfilment__packing_packshipment_add_waybill',
    form_name           => 'waybillForm',
    form_description    => 'Return Air Waybill',
    assert_location     => qr!^/Fulfilment/Packing/PackShipment!,
    transform_fields    => sub {
        my ($self, %args) = @_;
        if (!exists $args{return_waybill}) {
            die 'We need a return_waybill';
        }
        return \%args;
    },
);

=head2 flow_mech__fulfilment__packing_packshipment_complete

Press the "Packing Complete" button.

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packing_packshipment_complete',
    form_name         => 'completePack',
    form_description  => 'complete pack',
    assert_location   => qr!^/Fulfilment/Packing!,
    transform_fields  => sub { { complete_pack => 'yes' } }
);

=head2 flow_mech__fulfilment__packing_packshipment_follow_redirect

Follow Javascript redirect in DC1. Eww!
In DC2 this should be extended to click the button for the same effect

=cut

sub flow_mech__fulfilment__packing_packshipment_follow_redirect {
    my $self = shift;
    my ($url) = ( $self->mech->content =~ m/document.location.href\s*=\s*\"(.*)\"/i );
    $self->mech->get_ok($url, "Followed javascript redirect oK");
}

=head2 flow_mech__fulfilment__on_hold

Loads the list of shipments that are presently on hold.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__on_hold',
    page_description => 'Shipments On Hold',
    page_url         => '/Fulfilment/OnHold'
);

=head2 flow_mech__fulfilment__on_hold__select_incomplete_pick_shipment

Follow a link to a shipment currently listed in the 'Incomplete Pick' section.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__on_hold__select_incomplete_pick_shipment',
    link_description => 'Select Shipment On Hold',
    assert_location  => qr!^/Fulfilment/OnHold!,
    transform_fields => sub {
        my $shipment_id = $_[1];
        note "Shipment ID: $shipment_id";
        return { text      => $shipment_id,
                 url_regex => qr!^/Fulfilment/OnHold/OrderView\?order_id=\d+$!, }
    }
);

=head2 flow_mech__fulfilment__on_hold__hold_shipment

Follow the 'Hold Shipment' link on an On-Hold Order View page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__on_hold__hold_shipment',
    link_description => 'Hold Shipment',
    assert_location  => qr!^/Fulfilment/OnHold/OrderView\?order_id=\d+$!,
    find_link        => { text => 'Hold Shipment',
                  url_regex => qr!^/Fulfilment/OnHold/HoldShipment\?order_id=\d+\&shipment_id=\d+$! }
);


=head2 flow_mech__fulfilment__on_hold__release_shipment

Follow the 'Release Shipment' link on the Hold Shipment page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__on_hold__release_shipment',
    link_description => 'Release Shipment',
    assert_location  => qr!^/Fulfilment/OnHold/HoldShipment\?order_id=\d+\&shipment_id=\d+!,
    find_link        => { text => 'Release Shipment',
                  url_regex => qr!^/Fulfilment/OnHold/ChangeShipmentStatus\?action=Release\&order_id=\d+\&shipment_id=\d+$! }
);



my $create_subref_for_checkshipment_exception = sub {
    my ( $form_name ) = shift;
    return sub {
        my ( $self, $id ) = @_;

        my %sid_lookup = map {
            my $shipment_item_id = $_->{'Shipment Item ID'};
            if ( $shipment_item_id ) {
                (
                    $shipment_item_id => $shipment_item_id,
                    $_->{'SKU'} => $shipment_item_id

                )
            } else {
                ();
            }
        } @{ $self->mech->as_data()->{'shipment_items'} };

        my $shipment_item = $sid_lookup{ $id };
        croak "Can't find an item matching [$id]" unless $shipment_item;

        return $form_name . '-item-' . $shipment_item;
    }
};

=head2 flow_mech__fulfilment__packing_checkshipmentexception_ok

Marks an item as Ok in a Packing Exception tote

Accepts a shipment id or a SKU as the single argument

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packing_checkshipmentexception_ok_sku',
    form_name         => $create_subref_for_checkshipment_exception->('missing'),
    form_button       => 'item_ok',
    form_description  => 'mark item ok',
    assert_location   => qr!^/Fulfilment/Packing/CheckShipmentException!,
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_scanoutpeitem_sku',
    scan_description => 'SKU',
    assert_location  => qr!^/Fulfilment/PackingException/ScanOutPEItem!
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_scanoutpeitem_tote',
    scan_description => 'Tote ID',
    assert_location  => qr!^/Fulfilment/PackingException/ScanOutPEItem!
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_scanoutpeitem_location',
    scan_description => 'Location ID',
    assert_location  => qr!^/Fulfilment/PackingException/ScanOutPEItem!
);

=head2 task__fulfilment__packing_scanoutpeitem_to_putaway($container_id, $sku) : $self

Scan $sku into either a Container ($container_id) or a Location
depending on which type of intransit method is used.

=cut

sub task__fulfilment__packing_scanoutpeitem_to_putaway {
    my ($self, $container_id, $sku) = @_;

    my $putaway_test = Test::XT::Fulfilment::Putaway->new_by_type({
        flow => $self,
    });
    $putaway_test->flow_mech__fulfilment__packing_scanoutpeitem(
        $container_id,
        $sku,
    );

    return $self;
}



=head2 flow_mech__fulfilment__packing_checkshipmentexception_faulty

Start the process of removing a faulty item from a Packing Exception tote

Accepts a shipment id or a SKU as the single argument

=cut

__PACKAGE__->create_form_method(
    method_name       => 'flow_mech__fulfilment__packing_checkshipmentexception_faulty',
    form_name         => $create_subref_for_checkshipment_exception->('faulty'),
    form_description  => 'start faulty process',
    assert_location   => qr!^/Fulfilment/Packing/CheckShipmentException!,
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_checkshipmentexception_faulty_sku',
    scan_description => 'SKU',
    assert_location  => qr!^/Fulfilment/PackingException/ScanOutPEItem!
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__packing_checkshipmentexception_faulty_tote',
    scan_description => 'Tote ID',
    assert_location  => qr!^/Fulfilment/PackingException/ScanOutPEItem!
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__commissioner',
    page_description => 'Commissioner',
    page_url         => '/Fulfilment/Commissioner'
);

sub flow_mech__fulfilment__commissioner__check_is_in_cage {
    my $self = shift;
    $self->mech->use_first_page_form->tick("is_container_in_cage", 1);
}

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__commissioner__submit_induct_to_packing',
    scan_description => 'Container or Shipment Number',
    assert_location  => qr!^/Fulfilment/Commissioner!,
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__dispatch',
    page_description => 'dispatch list',
    page_url         => '/Fulfilment/Dispatch'
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__dispatch_shipment',
    scan_description => 'Shipment ID',
    assert_location  => qr!^/Fulfilment/Dispatch!,
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__labelling',
    page_description => 'labelling page',
    page_url         => '/Fulfilment/Labelling'
);

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__labelling_scan_box',
    scan_description => 'box number',
    assert_location  => qr!^/Fulfilment/Labelling!,
);

=head2 flow_mech__fulfilment__selection_next

Follows the 'Next' link from a Selection page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__selection_next',
    link_description => 'Next',
    find_link        => { text => 'Next' },
    assert_location  => qr!^/Fulfilment/Selection!
);

sub flow_mech__fulfilment__selection_find_shipment {
    my ( $self, $shipment_id ) = @_;

    my $shipments = $self->mech->as_data->{'shipments'};
    my @hits = grep { $_->{"Shipment Number"}->{value} == $shipment_id }
        @{$shipments};

    if (scalar @hits > 0) {
        is(scalar @hits, 1, 'only one match found');
        return $hits[0];
    }

    return;
}

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__airwaybill',
    page_description => 'Airway Bill',
    page_url         => '/Fulfilment/Airwaybill'
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__airwaybill_shipment_id',
    form_name        => 'airwayForm',
    form_description => 'Shipment Number',

    assert_location  => '/Fulfilment/Airwaybill',
    transform_fields => sub {
        my ( $self, $args ) = @_;

        return {
            shipment_id => $args->{shipment_id},
        }
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__airwaybill_airwaybills',
    form_name        => 'allocateAirwayForm',
    form_description => 'Enter Airwaybill',

    assert_location  => qr{^/Fulfilment/Airwaybill/AllocateAirwaybill?.*shipment_id=\d+},
    transform_fields => sub {
        my ( $self, $args ) = @_;

        my ( $out_airway, $ret_airway ) = Test::XTracker::Data->generate_air_waybills;
        return {
            out_airway => $args->{outward} // $out_airway,
            ret_airway => $args->{'return'} // $ret_airway,
        }
    },
);

=head2 mech__fulfilment__set_packing_station

This method calls the select packing station and submits any valid
value for the given channel.

Only runs in DCs which require a packing station to be set.

=cut

sub mech__fulfilment__set_packing_station {
    my ( $self, $channel_id ) = @_;
    config_var("Fulfilment", "requires_packing_station") or return $self;

    $self
        ->flow_mech__fulfilment__select_packing_station
        ->flow_mech__fulfilment__select_packing_station_submit(
            channel_id => $channel_id,
        );
}

=head2 PREMIER ROUTING

=head2 flow_mech__fulfilment__premier_routing

This will take you to the menu option 'Fulfilment->Premier Routing'.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__premier_routing',
    page_description => 'Premier Routing',
    page_url         => '/Fulfilment/PremierRouting',
);


=head2 flow_mech__fulfilment__premier_routing__export_manifest

This will generate a Preimier Routing file for all Shipments that are ready.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__premier_routing__export_manifest',
    form_name        => 'exportForm',
    form_description => 'generate a Premier Routing file',
    assert_location  => qr{^/Fulfilment/PremierRouting$},
    transform_fields => sub {
                my ( $mech, $args )     = @_;

                $args   //= {};

                return {
                        %{ $args },
                    };
            },
);

=head2 flow_mech__fulfilment__premier_routing__click_on_export_number

    $framework->flow_mech__fulfilment__premier_routing__click_on_export_number( $routing_export_id );

This will click on a particular Routing Export Id in the List of Exports on the Premier Routing page.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__premier_routing__click_on_export_number',
    link_description => 'click on a Premier Routing Export Number',
    assert_location  => qr{^/Fulfilment/PremierRouting},
    transform_fields => sub {
                my ( $mech, $routing_id )   = @_;
                return {
                    url_regex => qr!.*\?routing_export_id=${routing_id}$!,
                }
        },
);

=head2 flow_mech__fulfilment__premier_routing__complete_export

This will complete the Premier Routing Export which will then Dispatch the Shipments.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__premier_routing__complete_export',
    form_name        => 'exportForm',
    form_description => 'Complete Premier Routing file',
    assert_location  => qr{^/Fulfilment/PremierRouting\?routing_export_id=\d+},
    transform_fields => sub {
                my ( $mech, $args )     = @_;

                $args   //= {};

                return {
                        %{ $args },
                        status  => 'Complete',
                        submit  => 'COMPLETE EXPORT >',
                    };
            },
);

# returns the name of the form for the given Sales
# Channel Config section on the 'Fulfilment->DDU' page
sub _fufilment_ddu_list_page_form_name {
    my ( $mech, $channel_config )       = @_;
    return 'dduForm_' . $channel_config;
}

=head2 flow_mech__fulfilment__ddu

Goes to the Fulfilment->DDU page.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__ddu',
    page_description => 'Fulfilment DDU Page',
    page_url         => '/Fulfilment/DDU',
);

=head2 flow_mech__fulfilment__ddu_send_request_email

    $framework->flow_mech__fulfilment__ddu_send_request_email( $channel_config, [ $shipment_id, ... ] );

This sends a Request for the Customer to Accept DDU Shipping Terms for the Shipment Ids passed.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__ddu_send_request_email',
    form_name        => sub { return _fufilment_ddu_list_page_form_name( @_ ); },
    form_description => 'Send DDU Email Request',
    assert_location  => qr{^/Fulfilment/DDU},
    transform_fields => sub {
                my ( $self, $channel_config, $shipment_ids )    = @_;

                my $mech    = $self->mech;

                $mech->form_name( _fufilment_ddu_list_page_form_name( $mech, $channel_config ) );

                foreach my $ship_id ( @{ $shipment_ids } ) {
                    $mech->tick( $ship_id, 'notify' );
                }

                return;
            },
);

=head2 flow_mech__fulfilment__ddu_send_request_followup_email

    $framework->flow_mech__fulfilment__ddu_send_request_followup_email( $channel_config, [ $shipment_id, ... ] );

This sends a Follow-Up Request for the Customer to Accept DDU Shipping Terms for the Shipment Ids passed.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__ddu_send_request_followup_email',
    form_name        => sub { return _fufilment_ddu_list_page_form_name( @_ ); },
    form_description => 'Send DDU Email Request',
    assert_location  => qr{^/Fulfilment/DDU},
    transform_fields => sub {
                my ( $self, $channel_config, $shipment_ids )    = @_;

                my $mech    = $self->mech;

                $mech->form_name( _fufilment_ddu_list_page_form_name( $mech, $channel_config ) );

                foreach my $ship_id ( @{ $shipment_ids } ) {
                    $mech->tick( $ship_id, 'followup' );
                }

                return;
            },
);

=head2 flow_mech__fulfilment__ddu_set_ddu_status_link

    $framework->flow_mech__fulfilment__ddu_set_ddu_status_link( $shipment_id );

This goes to the page where a user can Accept the DDU Charges when the Customer has responded to the email requests.

=cut

__PACKAGE__->create_link_method(
    method_name      => 'flow_mech__fulfilment__ddu_set_ddu_status_link',
    link_description => 'Set DDU Status page',
    assert_location  => qr{^/Fulfilment/DDU},
    transform_fields => sub {
        my ( $self, $shipment_id )  = @_;
        return { text => $shipment_id };
    }
);

=head2 flow_mech__fulfilment__ddu_set_ddu_status_submit

    $framework->flow_mech__fulfilment__ddu_set_ddu_status_submit( {
        authorise   => 'no' | 'yes' | 'authorise_all',
    } );

This will submit the page to set the DDU Status for a Shipment based on the options you pass in:

    * 'no'      - will refuse charges
    * 'yes'     - will accept charges
    * 'authorise_all' - will accept these charges and subsequent charges

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__ddu_set_ddu_status_submit',
    form_name        => 'acceptDDUcharges',
    form_description => 'Set DDU Status',
    assert_location  => qr{^/Fulfilment/DDU/SetDDUStatus},
    transform_fields => sub {
        my ( $self, $args ) = @_;

        my $mech    = $self->mech;

        $mech->form_name('acceptDDUcharges');

        return {
            ( keys %{ $args } ? %{ $args } : () ),
        };
    },
);

=head2 flow_mech__fulfilment__induction

Display list of Containers ready for Packing, and Container scan form.

=cut

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__induction',
    page_description => '/Fulfilment/Induction Page',
    page_url         => '/Fulfilment/Induction'
);

=head2 flow_mech__fulfilment__induction__check_is_in_cage

Tick the "I am in the Cage" check box.

=cut

sub flow_mech__fulfilment__induction__check_is_in_cage {
    my $self = shift;
    $self->mech->use_first_page_form->tick("is_container_in_cage", 1);
}

=head2 flow_mech__fulfilment__induction_submit

Submits a container ID in the Induction screen

=cut

__PACKAGE__->create_scan_method(
    method_name      => 'flow_mech__fulfilment__induction_submit',
    scan_description => 'Container id scan',
    assert_location  => qr!^/Fulfilment/Induction!
);

=head2 flow_mech__fulfilment__induction_answer_submit

Answer the Can Convey? question.

=cut

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__induction_answer_submit',
    form_description => 'Can Convey question',
    assert_location  => qr!^/Fulfilment/Induction!,
    form_name        => 'canConveyQuestion',
    transform_fields => sub {
        my ( $self, $can_convey_answer ) = @_;
        return { can_be_conveyed => $can_convey_answer };
    },
);

__PACKAGE__->create_fetch_method(
    method_name      => 'flow_mech__fulfilment__goh_integration',
    page_description => 'GOH Integration page',
    page_url         => '/Fulfilment/GOHIntegration',
    params           => qw/ignore_cookies/,
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__select_goh_integration_lane',
    form_name        => 'select_goh_integration_lane',
    form_description => 'Choose to work on Integration station',
    assert_location  => qr|^/Fulfilment/GOHIntegration|,
    form_button      => 'select_integration_lane',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__select_goh_direct_lane',
    form_name        => 'select_goh_direct_lane',
    form_description => 'Choose to work on Direct station',
    assert_location  => qr|^/Fulfilment/GOHIntegration|,
    form_button      => 'select_direct_lane',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__scan_container_at_goh_integration',
    form_name        => 'scanning_form',
    form_description => 'At GOH Integration/Direct lane scan a container',
    assert_location  => qr!^/Fulfilment/GOHIntegration/\d+!,
    form_button      => 'scan',
    transform_fields => sub {
        my ( $self, $container_id ) = @_;
        return { container => $container_id };
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__scan_sku_at_goh_integration',
    form_name        => 'scanning_form',
    form_description => 'At GOH Integration/Direct lane scan a SKU',
    assert_location  => qr!^/Fulfilment/GOHIntegration/\d+!,
    form_button      => 'scan',
    transform_fields => sub {
        my ( $self, $sku ) = @_;
        return { sku => $sku };
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__missing_container_at_goh_integration',
    form_name        => 'scanning_form',
    form_description => 'At GOH Integration/Direct indicate that container is missing',
    assert_location  => qr!^/Fulfilment/GOHIntegration/\d+!,
    form_button      => 'missing_container',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__missing_sku_at_goh_integration',
    form_name        => 'missing_form',
    form_description => 'At GOH Integration/Direct indicate that SKU is missing',
    assert_location  => qr!^/Fulfilment/GOHIntegration/\d+!,
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_form_method(
    method_name      => 'flow_mech__fulfilment__goh_integration_full_tote',
    form_name        => 'full_tote_form',
    form_description => 'At GOH Integration/Direct indicate that tote is full',
    assert_location  => qr!^/Fulfilment/GOHIntegration/\d+!,
    form_button      => 'tote_full',
    transform_fields => sub {
        my ( $self, $args ) = @_;
        return $args;
    },
);

__PACKAGE__->create_fetch_method(
    method_name         => 'flow_mech__fulfilment__goh_integration_logged_out_user_access',
    page_description    => 'View GOH integration lane',
    page_url            => '/Fulfilment/GOHIntegration/1/view',
    assert_login_page   => 1,
);

=head1 TASK METHODS

=head2 task__selection

Selects a shipment as ready to be picked (Fulfilment->Selection)

    param - $shipment : XTracker::Schema::Result::Public::Shipment object for shipment to select

=cut

sub task__selection {
    my ($self, $shipment) = @_;

    # If no shipment supplied, assume user wants us to create one
    $shipment ||= $self->flow_db__fulfilment__create_order()->{shipment_object};

    $self->flow_mech__fulfilment__selection();
    $self->flow_mech__fulfilment__selection_submit( $shipment->id );

    return $shipment;
}

=head2 task__picking

Pick all the variants for a selected shipment (Fulfilment->Picking)

    param - $shipment : XTracker::Schema::Result::Public::Shipment object for shipment to pick

=cut

sub task__picking {
    my ($self, $shipment) = @_;

    # If no shipment supplied, assume user wants us to create one and process it up to this point
    $shipment ||= $self->task__selection();

    my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 });

    # Create a hash of skus where:
    # {
    #   sku => location,
    # }
    # Is this the best way to get this information?
    my @shipment_items = $shipment->shipment_items;
    my %skus = map { $_->get_true_variant->sku() => $self->_get_location($_) } @shipment_items;

    if(config_var('IWS', 'rollout_phase')) {

        $self->flow_wms__send_picking_commenced($shipment);
        # Fake a ShipmentReady from IWS emulating what previously was picking
        $self->flow_wms__send_shipment_ready(
            shipment_id => $shipment->id,
            container => { $container_id => [keys %skus] },
        );

    } elsif(config_var('PRL', 'rollout_phase')) {
        $self->flow_msg__prl__pick_shipment(
            shipment_id => $shipment->id,
            container => { $container_id => [keys %skus], },
        );
        $self->flow_msg__prl__induct_shipment( shipment_id => $shipment->id );
    } else {
        # Manual

        my $wms_to_xt = $self->wms_receipt_dir;

        # And pick it
        $self->flow_mech__fulfilment__picking();
        $self->flow_mech__fulfilment__picking_submit( $shipment->id );

        $wms_to_xt->expect_messages( {
            messages => [{
                'type'   => 'picking_commenced',
                'details' => { shipment_id => 's-'.$shipment->id },
            }]
        } );

        # Pick the individual skus
        for my $sku (keys %skus) {
            $self->flow_mech__fulfilment__picking_pickshipment_submit_location( $skus{$sku} );
            $self->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );
            $self->flow_mech__fulfilment__picking_pickshipment_submit_container( $container_id );
        }

        # Shipment is ready for packing
        $wms_to_xt->expect_messages({
            messages => [{
                type => 'shipment_ready',
            }],
        });

        # TODO: RAVNI still complains of unprocessed messages

    }

    return ($shipment, $container_id);
}

sub _get_location {
    my ($self, $shipment_item) = @_;

    my $location_obj = $shipment_item->get_true_variant->quantities->search_related_rs('location')->get_locations->first;
    return ($location_obj ? $location_obj->location: 'Unknown');
}

=head2 task__packing

Pack the shipment (Fulfilment->Packing)

    param - $shipment : XTracker::Schema::Result::Public::Shipment object for shipment to pack
    param - $args : Hashref of optional parameters:
        tote - A tote object that should be entered for packing rather than the shipment
        xt_to_wms - Test::XTracker::Artifacts::RAVNI instance to use to pickup messages from XT to WMS
        tote_empty - (Default = 1) Set to 0 to select 'no' when prompted if the current tote is empty

=cut

sub task__packing {
    my ($self, $shipment, $args) = @_;
    $args ||= {};

    my $tote = $args->{tote};

    # If no shipment supplied, assume user wants us to create one and process it up to this point
    ($shipment, $tote) = $self->task__picking() unless $shipment;

    my $xt_to_wms = $args->{xt_to_wms} || Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

    $self->mech__fulfilment__set_packing_station( $shipment->get_channel->id );

    # Select the shipment/tote for packing
    $self->flow_mech__fulfilment__packing;

    # Submit a tote if we have one, else the shipment
    $self->flow_mech__fulfilment__packing_submit( $tote || $shipment->id );

    # QC it
    $self->flow_mech__fulfilment__packing_checkshipment_submit();

    $xt_to_wms->expect_messages({
        messages => [{
            'type'   => 'shipment_received',
            'details' => { shipment_id => 's-'.$shipment->id }
        }]
    });

    # Enter the SKUs as packed
    $self->flow_mech__fulfilment__packing_packshipment_submit_sku( $_->get_true_variant->sku )
        for $shipment->shipment_items->search({ shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED });

    # Pick the box types they will be packed in
    my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 });
    $self->flow_mech__fulfilment__packing_packshipment_submit_boxes(
        channel_id  => $shipment->get_channel->id,
        tote_id     => $container_id,
    );

    # Might need an airway bill at this point
    if (!AWBs_are_present( { for => 'packing', on => get_shipment_info($self->dbh, $shipment->id ) } )) {
        my ( $out_awb, $ret_awb ) = Test::XTracker::Data->generate_air_waybills;
        $self->flow_mech__fulfilment__packing_packshipment_submit_waybill($ret_awb);

    }

    # Packing is complete
    $self->flow_mech__fulfilment__packing_packshipment_complete;

    $xt_to_wms->expect_messages({
        messages => [
            {
                'type'   => 'shipment_packed',
                'details' => { shipment_id => 's-' . $shipment->id }
            },
        ]
    });

    # Page would usually redirect via JS (no really), so we'll have to do it ourselves
    # (And yes that's right, someone thought it would be great fun to use the shipment_id var to contain... a container_id...
    # Whoever you are, you're going on my 'list' :p)
    if(config_var('DistributionCentre','name') eq 'DC1') {
        $self->mech->get("/Fulfilment/Packing/CheckShipment?auto=completed&shipment_id=". ($tote || $container_id));
    } elsif(config_var('DistributionCentre','name') eq 'DC2') {
        #$self->mech->post("/Fulfilment/Packing/CheckShipment?shipment_id=". ($tote || $container_id));
        $self->flow_mech__fulfilment__packing();
        $self->flow_mech__fulfilment__packing_submit( ($tote || $container_id) );
    }

    # Confirm we have an empty tote
    my $tote_empty = (defined($args->{tote_empty}) ? $args->{tote_empty} : 1);
    $self->flow_mech__fulfilment__packing_emptytote_submit(($tote_empty ? 'yes' : 'no'));

    return $shipment;
}

=head2 task__packing__cancelled_order(:$shipment_row) : $packing_exception_container_id

Accept a Shipment with a cancelled order at packing.

The Packer will be asked if the container is empty. It is not, so the
SKUs are scanned into a new Container. The Packer then Completes this
and is again asked if the Container is empty. It is.

Return the $packing_exception_container_id, i.e. the container the
items were scanned into, and which should be sent to PE.

=cut

sub task__packing__cancelled_order {
    my ($self, $args) = @_;
    my $shipment_row = $args->{shipment_row};
    my $container_row = $args->{container_row};

    $self->mech__fulfilment__set_packing_station( $shipment_row->get_channel->id );
    $self->flow_mech__fulfilment__packing;
    $self->flow_mech__fulfilment__packing_submit( $container_row->id );

    note "EmptyTote - no, items remaining";
    $self->flow_mech__fulfilment__packing_emptytote_submit("no");

    my $packing_exception_container_row
        = $self->task__packing__scan_orphaned_shipment_into_container({
            shipment_row => $shipment_row,
        });

    note "EmptyTote - yes, tote's empty";
    $self->flow_mech__fulfilment__packing_emptytote_submit("yes");

    my $container_id = $container_row->id;
    $self->mech->has_feedback_success_ok(
        "Packing of container $container_id complete. Please set aside and scan a new container",
    );

    return $packing_exception_container_row;
}

=head2 task__packing__scan_orphaned_shipment_into_container(:$shipment_row) : $packing_exception_container_id

Accept a Shipment with a cancelled order at packing, after answering
"No" to "Is the tote emtpy?".

The SKUs are scanned into a new Container. The Packer then Completes
this and is again asked if the Container is empty. (this method does
not include the Packer answering that question)

Return the $packing_exception_container_row, i.e. the container the
items were scanned into, and which should be sent to PE.

=cut

sub task__packing__scan_orphaned_shipment_into_container {
    my ($self, $args) = @_;
    my $shipment_row = $args->{shipment_row};

    my $packing_exception_container_id
        = Test::XT::Data::Container->get_unique_id({
            how_many => 1,
        });

    note "Scan items into the new Tote bound for PackingException";
    for my $shipment_item_row ($shipment_row->shipment_items) {
        my $wms_receipt_dir = $self->wms_receipt_dir;
        $self->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item(
            $shipment_item_row->get_sku,
        );
        $self->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote(
            $packing_exception_container_id
        );

        if ( ! config_var('IWS', 'rollout_phase')) {
            # WMS::ItemMoved sends WMS::MovedCompleted. This is sent
            # back by RAVNI, which is running instead of IWS.
            $wms_receipt_dir->expect_messages({
                messages => [ { type => 'moved_completed' } ],
            });
        }
    }
    $self->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete;

    note "The Packer is now asked 'Is the tote empty?'";

    return $self->schema->find( Container => $packing_exception_container_id );
}

=head2 task__labelling

Label the boxes in a shipment (Fulfilment->Labelling)

    param - $shipment : XTracker::Schema::Result::Public::Shipment object to label

=cut

sub task__labelling {
    my ($self, $shipment) = @_;

    # If no shipment supplied, assume user wants us to create one and process it up to this point
    $shipment ||= $self->task__packing();

    if(config_var('Fulfilment', 'labelling_subsection')) {
        $self->flow_mech__fulfilment__labelling();
        $self->flow_mech__fulfilment__labelling_scan_box($_->id) for $shipment->shipment_boxes();
    }

    return $shipment;
}

=head2 task__dispatch

Dispatch the shipment (Fulfilment->Airwaybill)

    param - $shipment : XTracker::Schema::Result::Public::Shipment object to dispatch

=cut

sub task__dispatch {
    my ($self, $shipment) = @_;

    # If no shipment supplied, assume user wants us to create one and process it up to this point
    $shipment ||= $self->task__labelling();

    $self->flow_mech__fulfilment__dispatch();
    $self->flow_mech__fulfilment__dispatch_shipment($shipment->id);

    # Make sure the shipment has been update successfully
    $shipment->discard_changes();
    is($shipment->shipment_status_id, $SHIPMENT_STATUS__DISPATCHED, 'Shipment is in \'Dispatched\' status');

    return $shipment;
}

1; # "I think there is a world market for maybe five computers." - Thomas Watson, Chairman of IBM, in 1943
