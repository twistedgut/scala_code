package Test::NAP::Packing;

=head1 NAME

Test::NAP::Packing - Test Packing scenarios

=head1 DESCRIPTION

Test Packing scenarios.

#TAGS fulfilment packing prl ups xpath loops printer toobig needsrefactor needswork

=head1 METHODS

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;
use parent 'NAP::Test::Class';

use Test::XTracker::RunCondition export => [qw ($prl_rollout_phase)];

use Test::XTracker::RequiresAMQ;

use Test::XT::Flow;
use Test::XT::Fixture::Fulfilment::Shipment;
use Test::XTracker::Data;
use Test::XTracker::Mock::Handler;
use Test::XTracker::ParamCheck;
use Test::XTracker::PrintDocs;

use XTracker::Config::Local qw(
    :carrier_automation
    config_var
    sys_config_groups
);

use XT::Domain::PRLs;
use XTracker::Constants qw( :application );
use XTracker::Database::Profile qw( get_operator_preferences );
use XTracker::Database::Shipment qw( :carrier_automation );

use XTracker::Constants::FromDB qw(
    :authorisation_level
    :shipment_item_status
    :shipment_status
    :shipment_type
    :ship_restriction
);

use Data::Dump  qw( pp );
use Test::XTracker::Artifacts::RAVNI;

sub startup : Test(startup => 9) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    my %uses = (
        'NAP::Carrier' => [],
        'XTracker::Database::Shipment' => [qw{:DEFAULT :carrier_automation}],
        'XTracker::Navigation' => ['build_packing_nav'],
        'XTracker::Order::Actions::UpdateShipmentAirwaybill' => [],
        'XTracker::Order::Printing::ShipmentDocuments'
            => [qw{generate_shipment_paperwork print_shipment_documents}],
        'XTracker::Order::Printing::UPSBoxLabel' => ['print_ups_box_labels'],
        'XTracker::PrintFunctions' => [qw{print_ups_label get_printer_by_name}],
    );
    use_ok($_, @{$uses{$_}}) for keys %uses;

    can_ok("XTracker::Database::Shipment",qw(
        check_packing_station
        get_shipment_box_labels
        get_shipment_id_for_awb
    ));

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Data::Order',
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::CustomerCare',
            'Test::XT::Flow::PRL',
        ]
    );

    $self->{framework}->login_with_permissions(
        {
            perms => {
                $AUTHORISATION_LEVEL__MANAGER => [
                    'Customer Care/Order Search',
                    'Fulfilment/Airwaybill',
                    'Fulfilment/Dispatch',
                    'Fulfilment/Packing',
                    'Fulfilment/Picking',
                    'Fulfilment/Selection',
                    'Fulfilment/Labelling',
                    'Fulfilment/Invalid Shipments',
                ],
            },
            dept => 'Shipping',
        }
    );

    $self->{schema} = Test::XTracker::Data->get_schema;

    $self->{channel} = Test::XTracker::Data->channel_for_nap;
    $self->{channel_id} = $self->{channel}->id;

    $self->{customer} = Test::XTracker::Data->find_customer(
        { channel_id => $self->{channel_id} },
    );

    $self->{shipping_account} = Test::XTracker::Data->find_shipping_account(
        {
            channel_id => $self->{channel_id},
            acc_name => 'Domestic',
            carrier => 'DHL%',
        },
    );

    $self->{address} = Test::XTracker::Data->create_order_address_in('current_dc_premier');

    $self->{framework}
        ->mech__fulfilment__set_packing_station( $self->{channel_id} );
}

sub setup : Test(setup) {
    my ( $self ) = @_;
    # ensure tests begin without sticky pages
    $self->{schema}->resultset('Operator::StickyPage')->delete;
    $self->SUPER::setup;
}

sub teardown : Test(teardown) {
    my ( $self ) = @_;
    # ensure no sticky pages are left over
    $self->{schema}->resultset('Operator::StickyPage')->delete;
    $self->SUPER::teardown;
}

################################################################################

sub _grab_products_with_stock {
    my ( $self, $args ) = @_;

    # get some products
    $args->{force_create} = 1; # *sigh*
    my ( $channel, $pids ) = Test::XTracker::Data->grab_products( $args );
    # ensure there's stock for each variant
    foreach my $item ( @$pids ) {
        Test::XTracker::Data->ensure_variants_stock( $item->{pid} );
    }

    return ( $channel, $pids );
}

sub _get_order_and_hash {
    my ( $self, $args ) = @_;

    my $order_args = {
        base => {
            customer_id => $self->{customer}->id,
            channel_id => $args->{channel_id},
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id => $self->{shipping_account}->id,
            invoice_address_id => $self->{address}->id,
            shipping_charge_id => 4, # UK Express
        },
        attrs => [
            {
                price => 100.00,
            },
        ],
    };

    my ( $order, $order_hash ) = Test::XTracker::Data->create_db_order(
        Catalyst::Utils::merge_hashes( $order_args, $args ),
    );

    return ( $order, $order_hash );
}

################################################################################

=head2 test_cant_set_packing_station_name

=cut

sub test_cant_set_packing_station_name : Tests {
    my ( $self )  = @_;

    # Only try this if the XT is configured to require one
    return if config_var('Fulfilment','requires_packing_station');

    my $framework = $self->{framework};
    my $mech = $framework->mech;

    # Check we can't select a packing station
    $framework->errors_are_fatal(0);
    $framework->flow_mech__fulfilment__select_packing_station();
    $framework->errors_are_fatal(1);
    # Check error message
    $mech->has_tag('span','Page Not Available','Page Not Available Message Displayed');
    $mech->has_tag('p',"This page is not available for this DC, please click on the 'Back to Packing' link in the left hand menu to continue.",'Reason Displayed');

    # Check that 'back' link returns to packing
    $mech->follow_link_ok({ text_regex => qr/Back to Packing/ }, "Back to Packing Link");
    like( $mech->uri->path, qr{/Fulfilment/Packing$}, "Returned to Fulfilment/Packing page" );
}

=head2 test_packing_sticky

=cut

sub test_packing_sticky : Tests {
    my ( $self ) = @_;

    $self->_test_packing({ sticky => 1 });
}

=head2 test_packing_nonsticky

=cut

sub test_packing_nonsticky : Tests {
    my ( $self ) = @_;

    $self->_test_packing({ sticky => 0 });
}

################################################################################

sub _test_packing {
    my ( $self, $args ) = @_;

    my $framework = $self->{framework};
    my $mech = $framework->mech;

    my $schema = $self->{schema};

    my $channel_id  = $self->{channel_id};
    my $customer    = $self->{customer};

    # get shipping account for Domestic DHL
    my $shipping_account = $self->{shipping_account};

    my $address = $self->{address};

    my ($channel, $pids) = $self->_grab_products_with_stock({
        channel_id => $channel_id, how_many => 1,
    });

    my $sticky_pages = !!$args->{sticky};

    my ($order, $order_hash) = $self->_get_order_and_hash({
        pids => $pids, channel_id => $channel_id,
    });

    my $order_nr = $order->order_nr;

    note "Shipping Acc.: $shipping_account";
    note "Order Nr: $order_nr";
    note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;

    $mech->order_nr($order_nr);

    my ($ship_nr, $status, $category) = $self->gather_order_info($framework);
    note "Shipment Nr: $ship_nr";
    my $shipment    = $schema->resultset('Public::Shipment')->find($ship_nr);

    # The order status might be Credit Hold. Check and fix if needed
    if ($status eq "Credit Hold") {
        note 'Credit Hold';
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $mech->reload;
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
        ($ship_nr, $status, $category) = $self->gather_order_info($framework);
    }
    is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

    # Get shipment to packing stage
    my $skus= $mech->get_order_skus();
    if ($prl_rollout_phase) {
        Test::XTracker::Data::Order->allocate_shipment($shipment);
        Test::XTracker::Data::Order->select_shipment($shipment);
        my $container_id = Test::XT::Data::Container->get_unique_id({ how_many => 1 });
        $framework->flow_msg__prl__pick_shipment(
            shipment_id => $shipment->id,
            container => {
                $container_id => [keys %$skus],
            }
        );
        $framework->flow_msg__prl__induct_shipment( shipment_row => $shipment );
    } else {
        my $print_directory = Test::XTracker::PrintDocs->new();
        $mech->test_direct_select_shipment( $ship_nr );
        $skus               = $mech->get_info_from_picklist( $print_directory, $skus);
        $mech->test_pick_shipment( $ship_nr, $skus );
    }

    my $ship_item   = $shipment->shipment_items->first;
    # inner/outer boxes [0] - Inner, [1] - Outer
    # choose packaging appropriate to channel
    my @boxes = $channel->is_on_nap    ? ( 'NAP 3', '3' )
              : $channel->is_on_outnet ? ( 'ON BAG L', '4' )
              : die sprintf 'this test cannot run on channel ' . $channel->name;


    $framework->force_sticky_pages($sticky_pages);

    note 'check and begin packing shipment';
    $framework->flow_mech__fulfilment__packing();

    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework->flow_mech__fulfilment__packing_submit( $ship_nr );
    $xt_to_wms->expect_messages({
        messages => [ { type => 'shipment_received' }, ]
    });
    }

    # Check we have logged the message being sent
    ok($shipment->shipment_message_logs->count,
        sprintf( 'shipment received message logged for shipment %d', $shipment->id )
    );

    # Check document language
    like( $framework->mech->as_data->{shipment_summary}->{'Other Info'},
          qr/\slanguage\sdocuments/,
          'Document language information is present' );

    $framework
        ->flow_mech__fulfilment__packing_checkshipment_submit()
        ->assert_sticky;

    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

    note 'pack skus';
    foreach ( keys %{ $skus } ) {
        $framework
            ->flow_mech__fulfilment__packing_packshipment_submit_sku( $_ )
            ->assert_sticky;
    }

    if ($prl_rollout_phase) {
        # Check that a container_empty message hais been sent to
        # each configured PRL.
        my $number_of_prls = XT::Domain::PRLs::get_number_of_prls;
        $xt_to_prls->expect_messages({
            messages => [
                ({
                    '@type' => 'container_empty',
                }) x $number_of_prls,
            ],
        });
    }
    undef $xt_to_prls; # we're done with this for now, trigger the destructor

    note 'add box';
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            inner => $boxes[0],
            outer => $boxes[1],
        )
        ->assert_sticky;

    my ($awb) = Test::XTracker::Data->generate_air_waybills;

    my $should_test_awb = (config_var('DistributionCentre','expect_AWB'));
    $self->_test_awb( $shipment, $awb ) if $should_test_awb;

    note 'remove item from box and check item is updated and return AWB remains';
    $framework
        ->flow_mech__fulfilment__packing_packshipment_remove_item( shipment_item_id => $ship_item->id )
        ->assert_sticky;
    $shipment->discard_changes;
    $ship_item->discard_changes;
    is( $ship_item->shipment_box_id, undef, 'Box removed from item record' );
    $should_test_awb && is( $shipment->return_airway_bill, $awb, 'Return AWB Still There' );

    note 'add box and check shipment item is updated';
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            inner => $boxes[0],
            outer => $boxes[1],
        )
        ->assert_sticky;
    $shipment->discard_changes;
    $ship_item->discard_changes;
    my $assigned_shipment_box_id = $ship_item->shipment_box_id;
    ok( length( $assigned_shipment_box_id ), 'Box added to item record' );

    note 'remove box and check shipment box count is reduced but return AWB remains';
    my $box_count = $shipment->shipment_boxes->count();
    $framework
        ->flow_mech__fulfilment__packing_packshipment_remove_box(
            shipment_box_id => $shipment->shipment_boxes->first->id,
        )
        ->assert_sticky;
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_boxes->count(), '<', $box_count, 'Number of boxes has been reduced' );
    $should_test_awb && is( $shipment->return_airway_bill, $awb, 'Return AWB Still There' );

    my $existing_shipment_box = $self->find_or_create_other_shipment_box($shipment->id);

    note 'add an existing shipment box and check for duplicate box id error';
    $framework->errors_are_fatal(0);
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            inner => $boxes[0],
            outer => $boxes[1],
            shipment_box_id => $existing_shipment_box->id,
        );
    $framework
        ->mech
        ->has_feedback_error_ok(
            qr/Box label @{[$existing_shipment_box->id]} has already been used\. Please discard and scan a new one\./
        );
    $framework->errors_are_fatal(1);

    note 'add box again and check shipment box count is increased again';
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_boxes(
            inner => $boxes[0],
            outer => $boxes[1],
        )
        ->assert_sticky;
    $shipment->discard_changes;
    cmp_ok( $shipment->shipment_boxes->count(), '==', $box_count, 'Number of boxes match again' );


    note 'complete packing';
    $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $framework->flow_mech__fulfilment__packing_packshipment_complete();
    $framework->mech->has_feedback_success_ok( qr/Shipment @{[$shipment->id]} has now been packed\./ );
    $xt_to_wms->expect_messages({
        messages => [{
            type => 'shipment_packed',
            details => { spur => $self->dispatch_lane_number_for_shipment($shipment)},
        }]
    });
    }

    if ($prl_rollout_phase) {
        note "Expecting $box_count messages (one per box)";
        my $route_destination = XT::Domain::PRLs::get_conveyor_destination_id(
            "DispatchLanes/premier_dispatch",
        );
        $xt_to_prls->expect_messages({
            messages => [
                (
                    {
                        '@type' => 'route_request',
                        details => { destination => $route_destination },
                    },
                ) x $box_count,
            ],
        });
    }
    undef $xt_to_prls; # trigger the destructor

    return $framework;
}

sub find_or_create_other_shipment_box {
    my ( $self, $shipment_id ) = @_;

    my $schema = $self->{schema};
    my $shipment_box = $schema
        ->resultset('Public::ShipmentBox')
        ->search(
            {
                shipment_id => {
                    # look for a box belonging to some other shipment
                    '-and' => { '!=' => $shipment_id, '!=' => undef, },
                },
            },
            { rows => 1, }
        )
        ->single;
    return $shipment_box if $shipment_box;

    # If we don't have a shipment box let's create a new shipment that's in a
    # box
    return $self->{framework}
        ->packed_order->{shipment_object}->shipment_boxes->slice(0,0)->single;
}

sub _test_awb {
    my ( $self, $shipment, $awb ) = @_;

    note 'enter air waybill number';
    my $framework = $self->{framework};
    $framework
        ->flow_mech__fulfilment__packing_packshipment_submit_waybill( $awb )
        ->assert_sticky;

    $framework->mech->has_tag_like( 'h3', qr/Return Air Waybill/, 'See Return AWB heading' );
    $framework->mech->content_like( qr/Waybill:.*$awb/s, 'Found AWB entered previously' );

    note 'remove return AWB and check shipment is updated';
    $framework
        ->flow_mech__fulfilment__packing_packshipment_remove_waybill
        ->assert_sticky;
    $shipment->discard_changes;
    is( $shipment->return_airway_bill, 'none', 'Return AWB Removed' );

    note 'add return AWB again and check shipment is updated';
    $framework
        ->flow_mech__fulfilment__packing_packshipment_add_waybill( return_waybill => $awb )
        ->assert_sticky;
    $shipment->discard_changes;
    is( $shipment->return_airway_bill, $awb, 'Return AWB Added Again' );
}

sub dispatch_lane_number_for_shipment {
    my ( $self, $shipment ) = @_;

    # get number of lanes for this shipment type
    my $shipment_type = $shipment->shipment_type;

    # get lane number for current offset
    my $this_lane_offset = $shipment_type->dispatch_lane_offset->lane_offset;
    my $this_lane_number = $shipment_type->dispatch_lanes->slice($this_lane_offset, $this_lane_offset)->single->lane_nr;

    return $this_lane_number;
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
    my ( $self, $framework ) = @_;

    my $mech = $framework->mech;
    $mech->get_ok($mech->order_view_url);

    # On the order view page we need to find the shipment ID
    note $mech->order_view_url;
    my $ship_nr = $mech->get_table_value('Shipment Number:');

    my $status = $mech->get_table_value('Order Status:');

    my $category = $mech->get_table_value('Customer Category:');
    return ($ship_nr, $status, $category);
}

=head2 test_shipment_hazmat_flag

=cut

sub test_shipment_hazmat_flag : Tests {
    my ( $self ) = @_;

    my $schema = $self->{schema};
    my $dbh = $schema->storage->dbh;
    my $channel_id = $self->{channel}->id;

    my $order = $self->_create_an_order({ how_many => 2 });
    my $shipment = $order->shipments->first;

    # set first pid hazmat, second pid non-hazmat
    my ( $si_hazmat, $si_nonhazmat ) = $shipment->shipment_items;
    $si_hazmat->variant->product->update_or_create_related('link_product__ship_restrictions', {
            ship_restriction_id => $SHIP_RESTRICTION__HAZMAT });
    $si_hazmat->variant->product->shipping_attribute->update({ is_hazmat => 1 });
    $si_nonhazmat->variant->product->search_related(
        'link_product__ship_restrictions', {
            ship_restriction_id => $SHIP_RESTRICTION__HAZMAT,
        })->delete;
    $si_nonhazmat->variant->product->shipping_attribute->update({ is_hazmat => 0 });

    # verify shipment contains hazmat items
    ok $shipment->has_hazmat_items, 'shipment should contain hazmat items';

    # mark hazmat item cancel pending and verify shipment no longer contains hazmat items
    $si_hazmat->update_status( $SHIPMENT_ITEM_STATUS__CANCEL_PENDING, $APPLICATION_OPERATOR_ID );
    ok !$shipment->has_hazmat_items, 'shipment should no longer contain hazmat items';

    # mark hazmat item cancelled and verify shipment no longer contains hazmat items
    $si_hazmat->update_status( $SHIPMENT_ITEM_STATUS__CANCELLED, $APPLICATION_OPERATOR_ID );
    ok !$shipment->has_hazmat_items, 'shipment should no longer contain hazmat items';
}

=head2 test_required_parameters

Test that the functions are checking for required parameters.

=cut

sub test_required_parameters : Tests {
    my ( $self ) = @_;

    my $schema  = $self->{schema};
    my $dbh     = $schema->storage->dbh;
    my $channel_id = $self->{channel}->id;

    my $param_check = Test::XTracker::ParamCheck->new();

    my $order  = $self->_create_an_order();
    my $shipment_id= $order->shipments->first->id;

    my $ps_name = $self->get_packing_station_name;

    my $handler = Test::XTracker::Mock::Handler->new;

    $param_check->check_for_params(  \&build_packing_nav,
        'build_packing_nav',
        [ $schema ],
        [ "No Schema Connection Passed" ],
    );
    $param_check->check_for_params(  \&check_packing_station,
        'check_packing_station',
        [ $handler, 123, 1 ],
        [ "No Handler Passed", "No Shipment Id Passed", "No Sales Channel Id Passed" ],
        [ undef, undef, 0 ],
        [ undef, undef, "No Sales Channel Id Passed" ],
    );
    $param_check->check_for_hash_params(  \&check_packing_station,
        'check_packing_station',
        [ $handler, 123, 1 ],
        [
            { dbh => "No DBH Defined in Handler", schema => "No Schema Defined in Handler" },
        ],
    );
    $param_check->check_for_params( \&generate_shipment_paperwork,
        'generate_shipment_paperwork',
        [ $dbh, { shipment_id => $shipment_id, shipping_country => 'United States', } ],
        [ 'No Database Handle', 'No Arguments Passed' ]
    );
    $param_check->check_for_hash_params(  \&generate_shipment_paperwork,
        'generate_shipment_paperwork',
        [ $dbh, {
                shipment_id => $shipment_id,
                shipping_country => 'United States',
                packing_station => $ps_name
            }
        ],
        [ 'No Database Handle', {
                shipment_id => 'No Shipment Id Passed',
                shipping_country => 'No Shipping Country Passed',
                packing_station => undef
            },
        ],
        [ undef, {
                shipment_id => '-34',
                packing_station => 'This Wont Work'
            },
        ],
        [ undef, {
                shipment_id => 'No Shipment found for Shipment Id: -34',
                packing_station => "Can't Find a Document Printer for Packing Station: This Wont Work"
            },
        ]
    );
    $param_check->check_for_hash_params(  \&generate_shipment_paperwork,
        'generate_shipment_paperwork',
        [ $dbh, {
                shipment_id => $shipment_id,
                shipping_country => 'United States',
                doc_printer => 'Printer 1',
            }
        ],
        [ 'No Database Handle', {
                shipment_id => 'No Shipment Id Passed',
                shipping_country => 'No Shipping Country Passed',
                doc_printer => 'No Document Printer Specified',
            },
        ],
    );
    $param_check->check_for_params( \&get_shipment_box_labels,
        'get_shipment_box_labels',
        [ $dbh, $shipment_id ],
        [ 'No Database Handle', 'No Shipment Id Passed' ],
        [ undef, -34 ],
        [ undef, 'No Shipment found for Shipment Id: -34' ]
    );
    $param_check->check_for_params( \&get_shipment_id_for_awb,
        'get_shipment_id_for_awb',
        [ $dbh, { outward => '1' } ],
        [ 'No Database Handle', 'No Arguments Passed' ],
    );
    $param_check->check_for_hash_params(  \&get_shipment_id_for_awb,
        'get_shipment_id_for_awb',
        [ $dbh, { outward => '1' } ],
        [ 'No Database Handle', { outward => 'No AWB Type Specified' } ],
        [ undef, { outward => '' } ],
        [ undef, { outward => 'No AWB Passed to Search For' } ],
    );
    $param_check->check_for_params( \&print_ups_box_labels,
        'print_ups_box_labels',
        [ $dbh, $shipment_id, 'Label Printer' ],
        [ 'No Database Handle Passed', 'No Shipment Id Passed', 'No Label Printer Passed' ],
        [ undef, -34 ],
        [ undef, 'No Shipment found for Shipment Id: -34' ],
    );
    $param_check->check_for_params( \&print_ups_label,
        'print_ups_label',
        [ {
            prefix      => 'outward',
            unique_id   => 1234567890,
            label_data  => 'LABEL DATA',
            printer     => 'Printer 1',
            }
        ],
        [ 'No Args Passed' ],
    );
    $param_check->check_for_hash_params(  \&print_ups_label,
        'print_ups_label',
        [ {
            prefix      => 'outward',
            unique_id   => 1234567890,
            label_data  => 'LABEL DATA',
            printer     => 'Printer 1',
            }
        ],
        [ {
            prefix      => 'No Prefix Passed',
            unique_id   => 'No Unique Id Passed',
            label_data  => 'No Label Data Passed',
            printer     => 'No Printer Passed',
            },
        ],
        [ { printer     => "Printer Doesn't Exist", }, ],
        [ { printer     => "Couldn't Find Printer: Printer Doesn't Exist in Config File", }, ],
    );
}

=head2 test_packing_nav

This tests that the packing station nav is being built when it should be.

=cut

sub test_packing_nav : Tests {
    my ( $self ) = @_;

    my $schema  = $self->{schema};
    my $dbh     = $schema->storage->dbh;
    my $channel_id = $self->{channel}->id;
    my $dc_name = config_var('DistributionCentre','name');

    my $packing_nav = XTracker::Navigation::build_packing_nav($schema);
    ok($packing_nav, "$dc_name has a packing station");

    my $tmp;
    my $conf_grp= $schema->resultset('SystemConfig::ConfigGroup');
    my @ch_ids  = $schema->resultset('Public::Channel')->search()->all;

    my $othr_chan_ps;

    note "Testing Building Packing Station Nav";

    # set no packing station name initially
    my $operator_id = $APPLICATION_OPERATOR_ID;
    my $handler = Test::XTracker::Mock::Handler->new({
        operator_id => $operator_id,
    });

    my $operator = $schema->resultset('Public::Operator')->find($operator_id);
    $operator->update_or_create_preferences({ packing_station_name => '' });
    $handler->{data}{preferences} = get_operator_preferences( $dbh, $operator_id );

    my $order  = $self->_create_an_order();
    my $ship_id = $order->get_standard_class_shipment->id;
    note "Created Order: ".$order->id.", Shipment Id: ".$ship_id;

    $schema->txn_do( sub {
        my $grp;

        # delete any Packing Station Lists if there are any
        my $groups  = sys_config_groups( $schema, qr/PackingStationList/ );
        foreach ( @{ $groups } ) {
            $grp = $conf_grp->find( $_->{group_id} );
            note "Deleting Settings for Group '".$_->{name}."'";
            $grp->config_group_settings->delete;
            note "Deleting Group '".$_->{name}."' Id: ".$_->{group_id};
            $grp->delete();
        }

        note "PS = Packing Station";
        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        isa_ok($tmp,"HASH","check_packing_station returned a HASH");
        cmp_ok($tmp->{ok},"==",1,"No PS's defined, PS check OK");

        set_carrier_automated( $dbh, $ship_id, 1 );
        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        cmp_ok($tmp->{ok},"==",1,"No PS's defined, PS check still OK now Shipment is Automated");

        # create a basic Packing Station List in Config
        foreach my $channel ( $schema->resultset('Public::Channel')->all ) {
            my $config_section = $channel->business->config_section;
            $grp = $conf_grp->create( {
                name    => 'PackingStationList',
                channel_id => $channel->id,
                active  => 1,
            } );
            # create regular and channel specific packing station
            $grp->config_group_settings->populate([ map {
                {
                    setting  => 'packing_station',
                    value    => "PackingStation_$_->[0]",
                    sequence => $_->[1],
                    active   => 1,
                }
            } ([1,1], [2,2], [$config_section,3]) ]);

            # Set-up Channel Specific Packing Stations for an alternative channel
            unless ( $channel->id == $channel_id ) {
                $othr_chan_ps = "PackingStation_$config_section";
            }
        }

        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        isa_ok($tmp,"HASH","check_packing_station returned a HASH");
        cmp_ok($tmp->{ok},"==",0,"PS's defined & No PS Name, PS check NOT  OK");
        is($tmp->{fail_msg},"You Need to Set a Packing Station before Packing this Shipment","PS Fail MSG: Need to Set Station");

        # update preferences
        $handler->{data}{preferences}{packing_station_name} = 'PackingStation_1';
        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        cmp_ok($tmp->{ok},"==",1,"PS's defined & PS Name Set, PS check OK");

        # update preferences with an alternative channel than the Shipment Packing Station
        $handler->{data}{preferences}{packing_station_name} = $othr_chan_ps;
        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        cmp_ok($tmp->{ok},"==",0,"Other Channel to Shipment PS's defined & PS Name Set is Inactive, PS check NOT  OK");
        is($tmp->{fail_msg},"Your Packing Station is Not Valid, You Need to Change it Before Packing this Shipment","Other Channel PS Fail MSG: Need to Set Active Station for the same Channel as Shipment");

        # update preferences
        $handler->{data}{preferences}{packing_station_name} = 'PackingStation_1';

        # turn off current Packing Station
        $conf_grp->search( { channel_id => $channel_id, name => 'PackingStationList' } )
                    ->first
                    ->config_group_settings
                    ->search( { setting => 'packing_station', sequence => 1 } )
                    ->update( { active => 0 } );

        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        cmp_ok($tmp->{ok},"==",0,"PS's defined & PS Name Set is Inactive, PS check NOT  OK");
        is($tmp->{fail_msg},"Your Packing Station is Not Valid, You Need to Change it Before Packing this Shipment","PS Fail MSG: Need to Set Active Station");

        # make shipment not automated
        set_carrier_automated( $dbh, $ship_id, 0 );
        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        cmp_ok( $tmp->{ok},"==",
                !config_var('Fulfilment','requires_packing_station'),
                "PS's defined & PS Name Not Active but Shipment Not Automated, PS check NOT  OK as ps needed for matchup sheet on $dc_name");

        # make shipment automated again
        set_carrier_automated( $dbh, $ship_id, 1 );

        # update preferences
        $handler->{data}{preferences}{packing_station_name} = 'PackingStation_2';
        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        cmp_ok($tmp->{ok},"==",1,"PS's defined & PS Name Set to Active Station & Shipment is Automated, PS check OK");

        # turn off shipment's channel's Packing Station List
        $conf_grp->search( { name => 'PackingStationList', channel_id => $channel_id })
                    ->first
                    ->update( { active => 0 } );

        # Now there is a Packing Station List there should now be a Nav Built
        $tmp    = build_packing_nav( $schema );
        isa_ok($tmp,"HASH","Only 1 Channel has PS's Packing Nav Should Still Be Returned");
        is_deeply($tmp,{ title => 'Set Packing Station', url => '/Fulfilment/Packing/SelectPackingStation' },"Nav Has Correct Parts");

        $tmp    = check_packing_station( $handler, $ship_id, $channel_id );
        cmp_ok($tmp->{ok},"==",1,"No PS's defined for Shipment's Channel & PS Name Set, PS check OK");

        # clear packing station name
        $handler->{data}{preferences}{packing_station_name} = q{};
        $tmp = check_packing_station( $handler, $ship_id, $channel_id );
        cmp_ok($tmp->{ok},"==",1,"No PS's defined for Shipment's Channel & No PS Name Set, PS check OK");

        $schema->txn_rollback();
    } );
}

# creates an order
sub _create_an_order {
    my ( $self, $args ) = @_;

    my $how_many = $args->{how_many} // 1;

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        force_create => 1,
        how_many => $how_many,
        channel => $args->{channel},
    });
    Test::XTracker::Data->ensure_stock( $pids->[$_]{pid}, $pids->[$_]{size_id}, $channel->id )
        for (0..$how_many-1);

    my $address = Test::XTracker::Data->create_order_address_in('current_dc_premier');
    my $customer    = Test::XTracker::Data->find_customer({ channel_id => $channel->id });
    my $ship_account    = Test::XTracker::Data->find_shipping_account({
        carrier => config_var('DistributionCentre','default_carrier'),
        channel_id => $channel->id,
    });

    my $base = {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
    };

    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => $base,
        attrs => [
            { price => 100.00 },
        ],
    });

    return $order;
}

sub get_packing_station_name {
    my ( $self ) = @_;
    my $row = $self->{schema}->resultset('SystemConfig::ConfigGroup')
                             ->search( { name => { 'ilike' => 'PackingStation_%' } } )
                             ->slice(0,0)
                             ->single;
    return ( $row ? $row->name : q{} );
}

=head2 check_packing_summary_wording_on_packing_page

=cut

sub check_packing_summary_wording_on_packing_page :Tests() {
    my $self = shift;

    my $fixture = Test::XT::Fixture::Fulfilment::Shipment
        ->new({ flow => $self->{framework} })
        ->with_picked_shipment
        ->with_shipment_items_moved_into_additional_containers;

    my $flow            = $fixture->flow;
    my $shipment_id     = $fixture->shipment_row->id;
    my $packing_summary = $fixture->shipment_row->packing_summary;

    note 'Scan Shipment ID on Packing page';
    $flow->flow_mech__fulfilment__packing;
    $flow->flow_mech__fulfilment__packing_submit( $shipment_id );

    like(
        $flow->mech->app_info_message,
        qr/\Q$packing_summary\E/,
        "Packing summary is shown after Shipment ID was scanned",
    ) or diag("User message: " . $flow->mech->app_info_message);


    note 'Scan Container ID on Packing page';
    $flow->flow_mech__fulfilment__packing;
    $flow->flow_mech__fulfilment__packing_submit( $fixture->picked_container_id );

    like(
        $flow->mech->app_info_message,
        qr/\Q$packing_summary\E/,
        "Packing summary is shown after Container ID was scanned",
    ) or diag("User message: " . $flow->mech->app_info_message);
}

1;
