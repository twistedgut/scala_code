package Test::NAP::Packing::Totes;

use NAP::policy "tt",     'test';

=head1 NAME

Test::NAP::Packing::Totes - Push an order through to packing

=head1 DESCRIPTION

Drive the packing screens with various combinations of orders and totes.

#TAGS fulfilment packing packingexception order prl iws toobig orderview

=head1 METHODS

=cut

use parent 'NAP::Test::Class';

use Test::XTracker::RunCondition(
    export => [qw( $iws_rollout_phase $prl_rollout_phase )],
);

use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_item_status
    :physical_place
);
use Test::XTracker::Data qw/qc_fail_string/;
use Test::XT::Data::Container;
use List::Util qw(sum max);

use Test::XTracker::Artifacts::RAVNI;
use XT::Domain::PRLs;

sub startup : Tests(startup) {
    my ( $self ) = shift;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Feature::PipePage',
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Flow::WMS',
            'Test::XT::Flow::PRL',
        ],
    );
    $self->{framework}->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Customer Care/Customer Search',
            'Customer Care/Order Search',
            'Fulfilment/Picking',
            'Fulfilment/Packing',
            'Fulfilment/Packing Exception',
            'Fulfilment/Selection'
        ]},
        dept => 'Customer Care',
    });
    $self->{framework}->mech->force_datalite(1);
    $self->{totes} = [Test::XT::Data::Container->get_unique_ids({ how_many => 13 })];
    $self->clear_physical_place_at_packing;
}

=head2 prepare_orders

Prepare a set of orders, picked in the given totes.

If $product_count is a number, creates one order, otherwise it
assumes $product_count is an arrayref of numbers, one per order.

Returns a list of shipment ids.

The products are pre-selected, so each order has different products;
$force_eq requests that the same products be used for every order.

=cut

sub prepare_orders {
    my ($self,$product_count,$totes,$force_eq)=@_;

    my @totes=@$totes;

    my @orders;
    if (ref $product_count) {
        @orders = @$product_count;
    }
    else {
        @orders = ( $product_count );
    }

    my $total_products = $force_eq ? max(@orders) : sum(@orders);

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => $total_products
    });

    my $framework = $self->{framework};
    $framework->mech__fulfilment__set_packing_station( $channel->id );

    my %shipments;

    for my $p (@orders) {

        my @order_pids;

        if ($force_eq) {
            @order_pids = @$pids[0..$p-1];
        }
        else {
            @order_pids = splice @$pids,0,$p;
        }

        my %order_creation_args = (
            channel => $channel,
            products => \@order_pids,
        );
        if ($iws_rollout_phase) {
            my $product_data =
                $framework->flow_db__fulfilment__create_order_selected(
                    %order_creation_args
                );
            my $shipment_id = $product_data->{'shipment_id'};
            $shipments{$shipment_id}=$product_data;

            # Fake a ShipmentReady from IWS
            my $container;
            foreach my $item ( @{$product_data->{'product_objects'}} ) {
                my $tote_id = shift @totes;push @totes,$tote_id;
                push @{$container->{$tote_id}},$item->{'sku'};
            }

            $framework->flow_wms__send_shipment_ready(
                shipment_id => $shipment_id,
                container => $container,
            );
        } elsif ($prl_rollout_phase) {
            my $product_data =
                $framework->flow_db__fulfilment__create_order_selected(
                    %order_creation_args
                );
            my $shipment_id = $product_data->{'shipment_id'};
            $shipments{$shipment_id}=$product_data;

            # Fake the picking messages from the PRL
            my $container;
            foreach my $item ( @{$product_data->{'product_objects'}} ) {
                my $tote_id = shift @totes;push @totes,$tote_id;
                push @{$container->{$tote_id}},$item->{'sku'};
            }

            $framework->flow_msg__prl__pick_shipment(
                shipment_id => $shipment_id,
                container => $container,
            );
            $framework->flow_msg__prl__induct_shipment(
                shipment_id => $shipment_id,
            );
        } else {
            my $product_data =
                $framework->flow_db__fulfilment__create_order(
                    %order_creation_args
                );
            my $shipment_id = $product_data->{'shipment_id'};
            $shipments{$shipment_id}=$product_data;

            # Select the order, and start the picking process
            my $picking_sheet =
                $framework->flow_task__fulfilment__select_shipment_return_printdoc( $shipment_id );

            $framework
                ->flow_mech__fulfilment__picking
                ->flow_mech__fulfilment__picking_submit( $shipment_id );

            # Pick the items according to the pick-sheet
            for my $item (@{ $picking_sheet->{'item_list'} }) {
                my $location = $item->{'Location'};
                my $sku      = $item->{'SKU'};
                my $tote_id  = shift @totes;push @totes,$tote_id;

                $framework->flow_mech__fulfilment__picking_pickshipment_submit_location( $location );
                $framework->flow_mech__fulfilment__picking_pickshipment_submit_sku( $sku );

                $framework->catch_error(
                    'Unrecognized barcode format (EVIL-TOTE)',
                    "EVIL-TOTE scanned, correct warning message sent to the user",
                    flow_mech__fulfilment__picking_pickshipment_submit_container => "EVIL-TOTE" );

                $framework->flow_mech__fulfilment__picking_pickshipment_submit_container( $tote_id );
            }
        }

    }

    return \%shipments;
}

sub _pack_one_order_one_tote {
    my ($self, $container_id) = @_;

    my ($shipment_id)=keys %{$self->prepare_orders(2,[$container_id])};

    my $framework = $self->{framework};
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $shipment_id );

    my @items_by_id = @{$framework->mech->as_data()->{shipment_items}};

    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $container_id );

    is($framework->mech->uri->path,
       '/Fulfilment/Packing/CheckShipment',
       'shipment selected');

    my @items_by_tote = @{$framework->mech->as_data()->{shipment_items}};

    eq_or_diff \@items_by_id,\@items_by_tote, 'same shipment using id or tote';

    is_deeply [ map { $_->{Container} } @items_by_id ],
               [ $container_id, $container_id ],
                   'right tote shown';

    # start packing
    $framework->flow_mech__fulfilment__packing_checkshipment_submit();
    $framework->errors_are_fatal(0);
    $framework->mech->back;
    $framework->flow_mech__fulfilment__packing_checkshipment_submit();

    is($framework->mech->app_error_message,
         'QC has already been submitted, please see supervisor to resolve',
          "Expected error message");

    $framework->errors_are_fatal(1);
    $framework->assert_location(qr!^/Fulfilment/Packing/PackShipment!);
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $container_id );
    note "scanning a tote being packed does not go through QC again";
    $framework->assert_location(qr!^/Fulfilment/Packing/PackShipment!);
}

=head2 clear_physical_place_at_packing

=cut

sub clear_physical_place_at_packing {
    my $self = shift;

    note "* Setup";
    my @totes = @{$self->{totes}};
    my $container_id = $totes[12];
    my $container_row = $self->schema->resultset('Public::Container')->find_or_create({
        id => $container_id,
    });
    $container_row->move_to_physical_place( $PHYSICAL_PLACE__CAGE );

    note "* Run";
    $self->_pack_one_order_one_tote($container_id);

    note "*Test";
    $container_row->discard_changes();
    is($container_row->physical_place_id, undef, "physical_place_id cleared");
}

=head2 one_order_one_tote

Put a item shipment into a tote ready for packing.

Try packing with the shipment id, verify we display shipment items.

Try packing the container id, and verify we are on the check shipment page.

Verify the two pages display the same shipmen titems.

Submit the check shipment page, go back, and try submitting again - expect an
error about QC having already been submitted.

Go back to the packing page, try packing and check we don't need to QC the
items again.

=cut

sub one_order_one_tote : Tests {
    my $self = shift;
    $self->_pack_one_order_one_tote($self->{totes}[0]);
}

=head2 one_order_two_totes

Prepare one shipment containing two items in different totes, and get it ready
for shipping.

Begin packing the shipment by inputting the first tote. Submit the second tote
at the packing accumulator and verify we are packing the item in tote 1.

Do the same for tote 2.

Verify that we get an info message telling us that the shipment is contained in
multiple containers.

Go to the orderview page and cancel one of the items.

Back at the packing page submit the tote with the uncancelled item, and step
through the accumulator page, and fail the item.

Verify that the PIPE page we are brought to displays the correct data.

Scan the SKU into a new tote, test we display the correct data and mark as
complete.

If we're in PRL mode expect and one I<container_empty> message sent to each
PRL, and one I<route_request> message as well.

Verify we are at the EmptyTote page, and that both totes are shown.

Scan the cancelled SKU into a new tote.

If we're in IWS mode 'find' an unexpected SKU in the container and scan that
into the new tote too.

Mark the tote as empty and verify that the item is in the new tote.

If we're in IWS mode, go to the packing exception page and verify that under
the Containers with Unexpected or Cancelled Items section in the correct tab we
displayed the unexpected item's original tote.

=cut

sub one_order_two_totes : Tests {
    my $self = shift;

    my @totes = @{$self->{totes}};
    my ($shipment_id,$shipment_data)=%{$self->prepare_orders(2,[@totes[1,2]])};

    my $framework = $self->{framework};
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $shipment_id );

    my @items_by_id = @{$framework->mech->as_data()->{shipment_items}};

    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes[1] )
        ->flow_task__fulfilment__packing_accumulator( @totes[ 1, 2 ] );

    is($framework->mech->uri->path,
       '/Fulfilment/Packing/CheckShipment',
       'shipment selected by tote 1');

    my @items_by_tote1 = @{$framework->mech->as_data()->{shipment_items}};

    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes[2] )
        ->flow_task__fulfilment__packing_accumulator( @totes[ 1, 2 ] );

    is($framework->mech->uri->path,
       '/Fulfilment/Packing/CheckShipment',
       'shipment selected by tote 2');

    my @items_by_tote2 = @{$framework->mech->as_data()->{shipment_items}};

    eq_or_diff \@items_by_id,\@items_by_tote1, 'same shipment using id or tote 1';
    eq_or_diff \@items_by_id,\@items_by_tote2, 'same shipment using id or tote 2';

    is_deeply [ sort map { $_->{Container} } @items_by_id ],
               [ @totes[1,2] ],
                   'right totes shown';

    like($framework->mech->app_info_message(),
         qr{This shipment is contained in multiple containers},
         'info message multiple containers');
    like($framework->mech->app_info_message(),
         qr{$totes[1]},
         'info message, tote 1');
    like($framework->mech->app_info_message(),
         qr{$totes[2]},
         'info message, tote 2');
    is($framework->mech->app_status_message(),undef,'no status message');

    # now let's test canceling items

    my $order = $shipment_data->{order_object};
    my $canceled_sku = $shipment_data->{product_objects}[0]{sku};
    my $canceled_item = $shipment_data->{shipment_object}->shipment_items->search_by_sku($canceled_sku)->first;
    my $left_item = $shipment_data->{shipment_object}->shipment_items->search({id => { '!=' => $canceled_item->id }})->first;
    my $left_sku = $left_item->get_true_variant->sku;

    $framework
        ->flow_mech__customercare__orderview( $order->id )
        ->flow_mech__customercare__cancel_shipment_item()
        ->flow_mech__customercare__cancel_item_submit(
            $canceled_sku
        )->flow_mech__customercare__cancel_item_email_submit;

    # scanning the tote with only the canceled item in it won't start packing
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $left_item->container_id )
        ->flow_task__fulfilment__packing_accumulator( @totes[ 1, 2 ] );

    $framework->errors_are_fatal(0);
    $framework->flow_mech__fulfilment__packing_checkshipment_submit(
        fail => {
            $left_item->id => 'foo',
        }
    );

    my $operator_name = $framework->mech->app_operator_name();

    {
    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    $framework
        ->test_mech__pipe_page__test_items(
            handled => [],
            pending => [{
                SKU => $left_sku,
                QC => qc_fail_string('foo',$operator_name),
                Container => $left_item->container_id,
            }]
        )->flow_mech__fulfilment__packing_placeinpetote_scan_item( $left_sku )
    ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $totes[9] )
    ->test_mech__pipe_page__test_items(
        pending => [],
        handled => [{
            SKU => $left_sku,
            QC => qc_fail_string('foo',$operator_name),
            Container => $totes[9],
        }]
    )->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

    if($prl_rollout_phase) {
        my $number_of_prls = XT::Domain::PRLs::get_number_of_prls;
        $xt_to_prls->expect_messages({
            messages => [
                { 'type' => "route_request" },
                ({
                    type => 'container_empty',
                }) x $number_of_prls,
            ],
        });
    }
    }

    $framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote!);
    my $data = $framework->mech->as_data();

    is_deeply([sort @{$data->{totes}}],[sort @totes[1,2]],'both totes shown');

    $framework->flow_mech__fulfilment__packing_emptytote_submit('no');
    $framework
        ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($canceled_sku)
        ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes[8]);

    if ($iws_rollout_phase > 0) {
        # Let's inject an unexpected sku into one of the totes
        my ($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1
        });

        # This is not part of the order it just so happened to be found in the tote(s) by whoever was packing...
        # The tote in which it's found is of no particular importance right now.
        # We just want to make sure the original tote where it was found is displayed for the item.
        my $unexpected_sku = $pids->[0]{sku};
        $framework
            ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($unexpected_sku)
            ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($totes[8]);
    }
    $framework->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete;
    $framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote!);

    $canceled_item->discard_changes;
    is($canceled_item->container_id,$totes[8],'canceled item moved');

    if ($iws_rollout_phase > 0) {
        # Validate if this multi-tote order display the original tote correctly in the PE page

        $framework->without_datalite(
            flow_mech__fulfilment__packingexception => (),
        );
        $data = $framework->mech->as_data->{exceptions};
        my $channel_name = $shipment_data->{channel_object}->name;

        my $superfluous = $data->{$channel_name}->{'Containers with Unexpected or Cancelled Items'};

        # Grab the index for the array item which contains the original tote where the unexpected item was found
        my $original_totes = join(',',sort @totes[1,2]);
        my ($index) = grep { ( $superfluous->[$_]->{'Original Tote'}// '') eq $original_totes } 0..@{ $superfluous };
        ok ( defined($index) , "Form displays the unexpected item original tote(s)" );
    }
}

=head2 two_orders_one_tote

Prepare two shipments for packing, make sure they're in the same tote.

Start packing the tote.

Verify that we get an info message telling us that the tote contains more than
one shipment and to scan an item.

Scan a SKU and verify we get a success message telling us that the shipment was
selected by tote and SKU.

Verify we are packing the correct shipment and it contains the correct items.

Verify we have no messages for multi-order tote and no status messages.

Complete the packing steps and try packing the same tote again, verify that we
can start packing the shipment without needing to pass any additional
information, and make sure that we are packing the correct tote with no info
messages displayed on screen.

=cut

sub two_orders_one_tote : Tests {
    my $self = shift;

    my @totes = @{$self->{totes}};
    my $shipments = $self->prepare_orders([1,1],[$totes[3]]);
    my @shipment_ids=keys %{$shipments};

    my %items_by_id;

    my $framework = $self->{framework};
    for my $shipment_id (@shipment_ids) {
        $framework
            ->flow_mech__fulfilment__packing
            ->flow_mech__fulfilment__packing_submit( $shipment_id );
        $items_by_id{$shipment_id} = $framework->mech->as_data()->{shipment_items};
    }

    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes[3] );

    is($framework->mech->uri->path,
       '/Fulfilment/Packing',
       'shipment not selected yet');

    like($framework->mech->app_info_message(),
         qr{contains more than one shipment},
         '"more than one shipment" info');

    like($framework->mech->app_info_message(),
         qr{scan an item},
         '"scan an item" info');

    my $wanted_id=(keys %items_by_id)[0];
    $framework->flow_mech__fulfilment__packing_submit(
        $items_by_id{$wanted_id}->[0]->{SKU}
    );

    is($framework->mech->uri->path,
       '/Fulfilment/Packing/CheckShipment',
       'shipment selected by tote and sku');

    my $data = $framework->mech->as_data();

    eq_or_diff $data->{shipment_id},
               $wanted_id,
               'correct shipment selected';

    my @items_by_tote = @{$data->{shipment_items}};
    eq_or_diff \@items_by_tote,
               $items_by_id{$data->{shipment_id}},
               'same items using id or tote and sku';

    is_deeply [ sort map { $_->{Container} } @items_by_tote ],
               [ $totes[3] ],
                   'right tote shown';

    is($framework->mech->app_info_message(),undef,'no info message for multi-order tote');
    is($framework->mech->app_status_message(),undef,'no status message');

    $framework->flow_mech__fulfilment__packing_checkshipment_submit;

    for my $item (@items_by_tote) {
        my $sku = $item->{'SKU'};
        $framework->flow_mech__fulfilment__packing_packshipment_submit_sku( $sku );
    }

    # I think this should be fairly safe giving that we don't have multi channel orders
    my $channel_id = $shipments->{$shipment_ids[0]}->{channel_object}->id;
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes( channel_id => $channel_id )
        ->flow_mech__fulfilment__packing_packshipment_submit_waybill("0123456789",$data->{shipment_id})
        ->flow_mech__fulfilment__packing_packshipment_complete;


    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes[3] );

    is($framework->mech->uri->path,
       '/Fulfilment/Packing/CheckShipment',
       'shipment selected by tote alone, no longer multiple');

    my $data2 = $framework->mech->as_data();

    cmp_ok($data2->{shipment_id},'!=',$data->{shipment_id},
           'new shipment, same tote');

    @items_by_tote = @{$data2->{shipment_items}};

    eq_or_diff \@items_by_tote,
               $items_by_id{$data2->{shipment_id}},
               'new shipment using id or tote';

    is($framework->mech->app_info_message(),undef,'no info on last order for tote');
    is($framework->mech->app_status_message(),undef,'no status message');
}

=head2 two_orders_one_tote_test_exceptions

Get two shipments ready for packing and place them in the same tote.

Submit the tote at the packing page and then one of the SKUs, and verify that
we start packing the correct shipment.

Fail one of the items, verify that we are redirected to the PlaceInPEtote page,
and that we are displayed an error message telling us to send the shipment to
packing exception.

Scan the item, then a new tote and mark as complete.

Verify that we are back at the check shipment page, packing the B<other>
shipment in the tote.

Fail the item, repeat the place in packing exception tote, and verify that we
are redirected to the EmptyTote page for that container.

=cut

sub two_orders_one_tote_test_exceptions : Tests {
    my $self = shift;

    my @totes = @{$self->{totes}};
    my %shipments=%{$self->prepare_orders([1,1],[$totes[4]])};

    my $framework = $self->{framework};
    $framework->errors_are_fatal(0);
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes[4] );
    $framework->errors_are_fatal(1);

    is($framework->mech->uri->path,
       '/Fulfilment/Packing',
       'shipment not selected yet');

    $framework->flow_mech__fulfilment__packing_submit(
        (values %shipments)[0]->{product_objects}[0]->{sku}
    );

    is($framework->mech->uri->path,
       '/Fulfilment/Packing/CheckShipment',
       'shipment selected by tote and sku');

    my $data = $framework->mech->as_data();
    my $first_id = $data->{shipment_id};

    cmp_ok($first_id,'==',(keys %shipments)[0],
       'right shipment selected');

    $framework->errors_are_fatal(0);
    $framework->flow_mech__fulfilment__packing_checkshipment_submit(
        fail => {
            $data->{shipment_items}[0]{shipment_item_id} => 'foo',
        }
    );
    is($framework->mech->uri->path,
       '/Fulfilment/Packing/PlaceInPEtote',
       'pack QC fail requires putting items into another tote');
    like($framework->mech->app_error_message,
         qr{send to the packing exception desk},
         'packer asked to send shipment to exception desk');
    $framework->errors_are_fatal(1);

    $framework
        ->flow_mech__fulfilment__packing_placeinpetote_scan_item(
            (values %shipments)[0]->{product_objects}[0]->{sku}
        )->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $totes[10] )
        ->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

    is($framework->mech->uri->path,
       '/Fulfilment/Packing/CheckShipment',
       'shipment selected by tote alone, no longer multiple');

    $data = $framework->mech->as_data();
    my $second_id = $data->{shipment_id};

    cmp_ok($second_id,'==',(keys %shipments)[1],
       'right shipment selected');

    cmp_ok($second_id,'!=',$first_id,
           'new shipment, same tote');

    $framework->errors_are_fatal(0);
    $framework->flow_mech__fulfilment__packing_checkshipment_submit(
        fail => {
            $data->{shipment_items}[0]{shipment_item_id} => 'bar',
        }
    );
    is($framework->mech->uri->path,
       '/Fulfilment/Packing/PlaceInPEtote',
       'pack QC fail requires putting items into another tote');
    like($framework->mech->app_error_message,
         qr{send to the packing exception desk},
         'packer asked to send shipment to exception desk');

    $framework
        ->flow_mech__fulfilment__packing_placeinpetote_scan_item(
            (values %shipments)[1]->{product_objects}[0]->{sku}
        )->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $totes[11] )
        ->flow_mech__fulfilment__packing_placeinpetote_mark_complete();

    $framework->assert_location(qr!^/Fulfilment/Packing/EmptyTote\?container_id=!);
}

=head2 two_orders_one_tote_test_empty_tote

Prepare two shipments and place them in the same tote ready to pack.

Get another, different sku.

Submit the tote number and the unrelated sku, verify that we have an error
message telling us to put the item back an scan another item.

Back at the packing page submit the tote and check that we can't pack the
shipment yet (as we haven't inputted the sku).

Mark the tote as empty.

Verify that all the items are at packing exception and marked as I<Missing>. If
we're in IWS verify that we have received a I<shipment_received> and a
I<shipment_reject> message for each shipment.

=cut

sub two_orders_one_tote_test_empty_tote : Tests {
    my $self = shift;

    my @totes = @{$self->{totes}};
    my @shipment_ids = keys %{$self->prepare_orders([1,1],[$totes[5]])};

    # Let's get a totally different SKU
    my ($channel,$pids) = Test::XTracker::Data->grab_products({
        channel  => 'outnet',
        how_many => 1
    });

    note "Wrong sku ".$pids->[0]->{sku};

    my $framework = $self->{framework};
    $framework->errors_are_fatal(0);
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes[5] )
        ->flow_mech__fulfilment__packing_submit( $pids->[0]->{sku} );
    $framework->errors_are_fatal(1);

    $framework->mech->has_feedback_error_ok(qr/Please put the item back and scan another item/,"Put the item back and scan another one.");

    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes[5] );
    $framework->errors_are_fatal(1);

    is($framework->mech->uri->path,
       '/Fulfilment/Packing',
       'shipment not selected yet');

    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework->flow_mech__fulfilment__packing_empty_tote();

    my $schema=Test::XTracker::Data->get_schema();
    my $rs=$schema->resultset('Public::ShipmentItem');

    my @messages;
    for my $shipment_id (@shipment_ids) {
        my $ship_items=$rs->search({shipment_id=>$shipment_id});
        my $how_many=$ship_items->count();

        cmp_ok(
            $ship_items->count({
                shipment_item_status_id=>$SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION
            }),
            '==',$how_many,
            "all items of shipment $shipment_id are excepted",
        );

        cmp_ok(
            $ship_items->count({
                qc_failure_reason => 'Missing',
            }),
            '==',$how_many,
            "all items of shipment $shipment_id are marked missing",
        );

        push @messages,
            {
                'type'    => "shipment_received",
                details => {
                    shipment_id => "s-$shipment_id",
                },
            },
            {
                'type'    => "shipment_reject",
                details => {
                    shipment_id => "s-$shipment_id",
                },
            };

    }

    if ($iws_rollout_phase == 0) {
        # who knows what we should get in phase 0?
        $xt_to_wms->new_files();
    } else {
        $xt_to_wms->expect_messages({
            messages => \@messages
        });
    }

}

=head2 two_orders_one_tote_same_items

Create two shipments with the same item and put them same tote. Try submitting
the tote and verify that we get to a page where we get to input a SKU. Input a
SKU and check that we proceed to pack a (randomly selected) shipment.

=cut

sub two_orders_one_tote_same_items : Tests {
    my $self = shift;

    # force identical items
    my @totes = @{$self->{totes}};
    my %shipments=%{$self->prepare_orders([1,1],[$totes[6]], 1 )};

    my $framework = $self->{framework};
    $framework->errors_are_fatal(0);
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes[6] );
    $framework->errors_are_fatal(1);

    is($framework->mech->uri->path,
       '/Fulfilment/Packing',
       'shipment not selected yet');

    $framework->flow_mech__fulfilment__packing_submit(
        (values %shipments)[0]->{product_objects}[0]->{sku}
    );

    is($framework->mech->uri->path,
       '/Fulfilment/Packing/CheckShipment',
       'random shipment selected by tote and sku');
}

1;
