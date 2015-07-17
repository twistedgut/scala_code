package Test::NAP::Picking;

use NAP::policy "tt", 'test';

=head1 NAME

Test::NAP::Picking - Test the manual picking process (IWS and PRLs both off)

=head1 DESCRIPTION

Test the manual picking process in XT. If we're working with IWS or PRLs,
picking is done there instead of XT so this test shouldn't run.

#TAGS fulfilment picking loops voucher phase0 orderview

=head1 METHODS

=cut

use FindBin::libs;
use parent 'NAP::Test::Class';

use Test::XTracker::RunCondition iws_phase => 0, prl_phase => 0;

use Data::Dump  qw( pp );
use DateTime;

use Test::XTracker::Data;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::Mechanize;
use Test::XTracker::PrintDocs;
use Test::XT::Data::Container;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants qw( :application );
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :business
    :flow_status
    :order_status
    :shipment_class
    :shipment_hold_reason
    :shipment_item_status
    :shipment_status
    :shipment_type
);
use XT::Rules::Solve;

sub startup : Test(startup) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    use_ok( 'XTracker::Order::Printing::PickingList' );

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Data::Location',
            'Test::XT::Flow::CustomerCare',
        ],
    );

    # Create test locations (won't actually do anything if they're already
    # there)
    $self->{framework}->data__location__initialise_non_iws_test_locations;
    # FIXME: NAP ONLY TEST
    my $channel = $self->{channel} = Test::XTracker::Data->channel_for_nap;
    my $pids = $self->{pids} = (Test::XTracker::Data->grab_products({
        how_many => 1,
        channel_id => $channel->id,
        phys_vouchers   => {
            how_many => 1,
            want_stock => 3,
        },
        virt_vouchers   => {
            how_many => 1,
        },
    }))[1];
    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    $self->{customer} = Test::XTracker::Data->find_customer({ channel_id => $channel->id });

    # get shipping account for Domestic DHL
    $self->{shipping_account} = Test::XTracker::Data->find_shipping_account({
        channel_id  => $channel->id,
        acc_name    => 'Domestic',
        carrier     => 'DHL%',
    });
    $self->{premier_address} = Test::XTracker::Data->create_order_address_in(
        "current_dc_premier",
    );

    $self->{framework}->mech->do_login;
}

sub setup : Test(setup) {
    my ( $self ) = @_;
    $self->SUPER::setup;
    Test::XTracker::Data->set_department('it.god', 'Shipping');
    Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR);
    # Perms needed for the order process
    for (qw/Selection Picking/ ) {
        Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, $AUTHORISATION_LEVEL__OPERATOR);
    }
}

sub test_generate_picking_list : Tests {
    my ( $self ) = @_;
    can_ok( 'XTracker::Order::Printing::PickingList', 'generate_picking_list' );
    my $schema = $self->{framework}->schema;
    # For each search a sample and a customer shipment
    my %main_stock_floor = (
        $BUSINESS__NAP => 1,
        $BUSINESS__MRP => 1,
        $BUSINESS__JC => 1,
        $BUSINESS__OUTNET => 2,
    );
    for my $business_id ( keys %main_stock_floor ) {
        my $business = $schema->resultset('Public::Business')
                              ->find($business_id);
        my $channel = $business->channels->enabled->slice(0,0)->single;
        next unless $channel;
        my $pid_hash = (Test::XTracker::Data->grab_products({
            how_many => 1,
            channel_id => $channel->id,
        }))[1][0];

        my $shipping_account = Test::XTracker::Data->find_shipping_account({
            channel_id => $channel->id,
        });
        # Set stock in the locations
        my $variant = $pid_hash->{variant};
        $variant->quantities->delete;
        my $location_rs = $schema->resultset('Public::Location');
        my $standard_location
            = $location_rs->get_locations({floor => $main_stock_floor{$business_id}})
                          ->slice(0,0)
                          ->single;
        my $fasttrack_location
            = $location_rs->get_locations({floor => 3})->slice(0,0)->single;

        my $selected_count = $variant->selected;
        my $sample_selected_count = $variant->selected_for_sample;
        for (
            [ $standard_location, 'standard', ],
            [ $fasttrack_location, 'sample', ],
        ) {
            my ( $location, $shipment_type ) = @$_;

            next if $business_id == $BUSINESS__JC && $shipment_type eq 'sample';

            # Add stock to locations - this would be nicer if we could add a
            # key to limit our rs on the quantity table - but we have 'bad'
            # data in our db
            $_->[0]->search_related('quantities', {
                    variant_id => $variant->id,
                    channel_id => $channel->id,
                    status_id => $FLOW_STATUS__MAIN_STOCK__STOCK_STATUS,
                })->update_or_create({
                    quantity => $_->[1],
                }) for (
                    [$standard_location, $selected_count - $sample_selected_count + 1],
                    [$fasttrack_location, $sample_selected_count + 1],
                );

            my $sla_cutoff = DateTime->now(time_zone => config_var('DistributionCentre', 'timezone'));
            $sla_cutoff->add(hours => 12);
            my ($order) = Test::XTracker::Data->create_db_order({
                pids => [$pid_hash],
                base => {
                    customer_id => $self->{customer}->id,
                    channel_id => $channel->id,
                    shipment_type => $SHIPMENT_TYPE__PREMIER,
                    shipment_status => $SHIPMENT_STATUS__PROCESSING,
                    shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
                    shipping_account_id => $shipping_account->id,
                    invoice_address_id => $self->{premier_address}->id,
                    sla_cutoff => $sla_cutoff,
                },
            });
            my $shipment = $order->shipments->slice(0,0)->single;

            $shipment->update({
                shipment_class_id => $SHIPMENT_CLASS__TRANSFER_SHIPMENT
            }) if $shipment_type eq 'sample';

            my $print_directory = Test::XTracker::PrintDocs->new;
            XTracker::Order::Printing::PickingList::generate_picking_list(
                $schema, $shipment->id );
            # generate_picking_list doesn't actually advance the status of the
            # shipment items, so we do it manually
            $shipment->shipment_items->update({
                shipment_item_status_id => $SHIPMENT_ITEM_STATUS__SELECTED
            });

            my @doc = grep {
                $_->file_type eq 'pickinglist'
            } $print_directory->new_files;
            is( @doc, 1, "generated one pick list only for $shipment_type shipment " . $shipment->id );
            is( $doc[0]->as_data->{shipment_data}{'Shipment Number'}, $shipment->id,
                sprintf("picking list is for correct $shipment_type shipment (%s)", $shipment->id) );
            is( $doc[0]->as_data->{shipment_data}{'SLA Cut-Off'}, $sla_cutoff->strftime('%d-%m-%Y %H:%M'),
                "picking list SLA cut-off date is correct" );
        }
    }
}

sub test_picking_sheet_printer_rules : Tests {
    my ( $self ) = @_;

    my %tests = (
        1 => {
            $BUSINESS__NAP => [
                ['premier', 'fast_customer'],
                ['regular', 'regular_customer'],
                ['sample', 'stock_transfer'],
            ],
            $BUSINESS__MRP => [
                ['premier', 'fast_MRP'],
                ['regular', 'regular_MRP'],
                ['sample', 'stock_transfer'],
            ],
            $BUSINESS__JC => [
                ['premier', 'fast_JC'],
                ['regular', 'regular_JC'],
            ],
        },
        2 => {
            $BUSINESS__OUTNET => [
                ['premier', 'fast_OUTNET'],
                ['regular', 'regular_OUTNET'],
                ['sample', 'stock_transfer'],
            ],
        },
        3 => {
            $BUSINESS__NAP => [
                ['sample', 'stock_transfer'],
            ],
            $BUSINESS__MRP => [
                ['sample', 'stock_transfer'],
            ],
            $BUSINESS__OUTNET => [
                ['sample', 'stock_transfer'],
            ],
        },
        'other_floor' => {
            $BUSINESS__NAP => [
                ['premier', 'fast_customer'],
                ['regular', 'regular_customer'],
                ['sample', 'stock_transfer'],
            ],
            $BUSINESS__MRP => [
                ['premier', 'fast_MRP'],
                ['regular', 'regular_MRP'],
                ['sample', 'stock_transfer'],
            ],
            $BUSINESS__OUTNET => [
                ['premier', 'fast_OUTNET'],
                ['regular', 'regular_OUTNET'],
                ['sample', 'stock_transfer'],
            ],
            $BUSINESS__JC => [
                ['premier', 'fast_JC'],
                ['regular', 'regular_JC'],
            ],
        },
    );

    my $schema = $self->{framework}->schema;
    for my $floor ( keys %tests ) {
        my $location
            = $floor =~ m{^\d+$}
            ? $schema->resultset('Public::Location')
                     ->get_locations({ floor => $floor })
                     ->slice(0,0)
                     ->single
            : 'Unknown';
        for my $business_id ( keys %{$tests{$floor}} ) {
            my $business = $schema->resultset('Public::Business')
                                  ->find($business_id);
            my $channel = $business->channels->enabled->slice(0,0)->single;
            next unless $channel;
            my $pids = (Test::XTracker::Data->grab_products({
                how_many => 1,
                channel_id => $channel->id,
            }))[1];
            my $shipping_account = Test::XTracker::Data->find_shipping_account({
                channel_id => $channel->id,
            });
            for ( @{$tests{$floor}{$business_id}} ) {
                my ( $shipment_type, $expected_printer ) = @$_;
                my ($order) = Test::XTracker::Data->create_db_order({
                    pids => $pids,
                    base => {
                        customer_id => $self->{customer}->id,
                        channel_id => $channel->id,
                        shipment_type => ( $shipment_type eq 'regular'
                                        ? $SHIPMENT_TYPE__DOMESTIC
                                        : $SHIPMENT_TYPE__PREMIER ),
                        shipment_status => $SHIPMENT_STATUS__PROCESSING,
                        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
                        shipping_account_id => $shipping_account->id,
                        invoice_address_id => $self->{premier_address}->id,
                    },
                });

                my $shipment = $order->shipments->slice(0,0)->single;

                # Evil hack for sample shipment as I don't have time to
                # investigate setting one up properly
                $shipment->update({
                    shipment_class_id => $SHIPMENT_CLASS__TRANSFER_SHIPMENT,
                }) if $shipment_type eq 'sample';

                my $printer = XT::Rules::Solve->solve('PickSheet::select_printer' => {
                    'Business::config_section' => $channel->business,
                    'Shipment::is_premier' => $shipment,
                    'Shipment::is_transfer' => $shipment,
                    'Shipment::is_staff' => $shipment,
                    -schema => $schema,
                });
                is($printer, $expected_printer,
                    sprintf('%s printer on %s for stock on floor %s ok',
                        $shipment_type, $business->name, $floor) );
            }
        }
    }
}

sub test_pick_shipment_list : Tests {
    my ( $self ) = @_;

    my $mech = $self->{framework}->mech;
    my @tests = (
        {
            label => 'hide picking list from operator',
            auth => $AUTHORISATION_LEVEL__OPERATOR,
            show => 0,
        },
        {
            label => 'display picking list to manager',
            auth => $AUTHORISATION_LEVEL__MANAGER,
            show => 1,
        },
        {
            label => 'hide picking list from manager on handheld',
            auth => $AUTHORISATION_LEVEL__MANAGER,
            is_handheld => 1,
            show => 0,
        },
    );

    for my $test ( @tests ) {
        Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Picking', $test->{auth} );
        $mech->get_ok('/Fulfilment/Picking'
                    . ($test->{is_handheld} ? '?view=handheld' : q{}) );

        # Look for a picking list
        my $picking_list = 0;

        # Look for presence of picking list rows
        my $nodeset = $mech->find_xpath(q{//div[starts-with(@id,'tab')]//span[starts-with(@class,'title')]});
        $picking_list = 1 if $nodeset && $nodeset->size;

        # Look for the presence of the 'nothing to pick' marker
        my $nothing_to_pick = $mech->find_xpath(q{id('no-shipments')});
        $picking_list = 1 if $nothing_to_pick && $nothing_to_pick->size;

        is( $picking_list, $test->{show}, $test->{label} );
    }
}

sub phase_0_pick_product : Tests {
    my ( $self ) = @_;

    $self->pick_test({
        label   => 'Order with Normal Product Only',
        pids    => [ $self->{pids}[0] ],
    });
}

sub phase_0_pick_physical_voucher : Tests {
    my ( $self ) = @_;
    $self->pick_test({
        label   => 'Order with Physical Vouchers Only',
        pids    => [ $self->{pids}[1] ],
    });
}

sub phase_0_pick_product_physical_voucher_virtual_voucher : Tests {
    my ( $self ) = @_;
    $self->pick_test({
        label   => 'Order with Normal Product, Phys Voucher & Virt Voucher',
        pids    => $self->{pids},
        has_virtual_pid => 1,
    });
}

sub phase_0_handheld_pick_product_physical_voucher_virtual_voucher : Tests {
    my ( $self ) = @_;
    $self->pick_test({
        label   => 'Order with Normal Product, Phys Voucher & Virt Voucher on a HandHeld',
        pids    => $self->{pids},
        handheld=> 1,
        has_virtual_pid => 1,
    });
}

sub phase_0_pick_product_virtual_voucher : Tests {
    my ( $self ) = @_;
    $self->pick_test({
        label   => 'Order with Normal Product & Virt Voucher',
        pids    => [ map { $self->{pids}[$_] } (0,2) ],
        has_virtual_pid => 1,
    });
}

sub phase_0_incomplete_pick_product : Tests {
    my ( $self ) = @_;
    $self->pick_test({
        label   => 'Order with Normal Product, to test Incomplete Pick',
        pids    => [ $self->{pids}[0] ],
        incomplete_pick => 1,
    });
}

sub phase_0_handheld_incomplete_pick_product : Tests {
    my ( $self ) = @_;
    $self->pick_test({
        label   => 'Order with Normal Product, to test Incomplete Pick, on a HandHeld',
        pids    => [ $self->{pids}[0] ],
        incomplete_pick => 1,
        handheld => 1,
    });
}

sub pick_test {
    my ( $self, $args ) = @_;

    my $channel = $self->{channel};
    my $pids = $self->{pids};
    my $customer = $self->{customer};
    my $framework = $self->{framework};
    my $mech = $framework->mech;

    note "TESTING - $args->{label}";

    my ($order) = Test::XTracker::Data->create_db_order({
        base => {
            customer_id => $customer->id,
            channel_id  => $channel->id,
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
            shipping_account_id => $self->{shipping_account}->id,
            invoice_address_id => $self->{premier_address}->id,
            shipping_charge_id => 4,   # UK Express
        },
        pids => $args->{pids},
        attrs => [
            { price => 100.00 },
        ],
    });

    # Cargo-culting accepting an order if it's held :(
    # Doing this properly in flow is a big job...
    # The order status might be Credit Hold. Check and fix if needed
    if ( $order->order_status_id eq $ORDER_STATUS__CREDIT_HOLD ) {
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $framework->flow_mech__customercare__orderview( $order->id );
        $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
    }
    is( $order->discard_changes->order_status_id, $ORDER_STATUS__ACCEPTED,
        sprintf 'Order %d is accepted', $order->id );

    my $shipment = $order->get_standard_class_shipment;
    my $skus;
    # set virtual shipment items to be PICKED for purpose of test
    foreach my $item ( $shipment->shipment_items->all ) {
        $skus->{$item->get_true_variant->sku} = {};
        $item->create_related( 'shipment_item_status_logs', {
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__NEW,
            operator_id             => $APPLICATION_OPERATOR_ID,
        });
        if ( $item->is_virtual_voucher ) {
            $item->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED } );
            $item->create_related( 'shipment_item_status_logs', {
                shipment_item_status_id => $_,
                operator_id             => $APPLICATION_OPERATOR_ID,
            }) for $SHIPMENT_ITEM_STATUS__SELECTED, $SHIPMENT_ITEM_STATUS__PICKED;
        }
    }

    # Get shipment to picking stage
    my $vskus   = Test::XTracker::Data->stripout_vvoucher_from_skus( $skus );
    my $print_directory = Test::XTracker::PrintDocs->new();
    $mech->order_nr($order->order_nr); # we have to do this for some old flow stuff to work
    $mech->test_direct_select_shipment( $shipment->id );
    $skus = $mech->get_info_from_picklist($print_directory, $skus);

    # We should probably pass an arg here...
    if ( $args->{incomplete_pick} ) {
        $self->test_incomplete_pick( $shipment, $skus, $args);
    }
    else {
        $self->test_picking_shipment( $shipment, $skus, $vskus, $args );
    }
}

=head2 test_picking_shipment

    test_picking_shipment( $shipment, $skus, $vskus, $test );

This will test the actual picking of a shipment.

=cut

sub test_picking_shipment {
    my ( $self, $shipment, $skus, $vskus, $test )  = @_;

    # Test with Operator level access Should NOT see list of Shipments and make test quicker
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Picking', $AUTHORISATION_LEVEL__OPERATOR );

    my $mech = $self->{framework}->mech;
    $mech->get_ok( '/Fulfilment/Picking'
                 . ( $test->{handheld} ? '?view=HandHeld' : q{} ) );
    $mech->submit_form_ok({
        with_fields => { shipment_id => $shipment->id, },
        button => 'submit'
    }, sprintf("Begin picking shipment %d", $shipment->id));

    # make sure Virtual Voucher SKU's don't appear in the Page
    foreach my $sku ( keys %{ $vskus }) {
        $mech->content_unlike( qr/$sku/,
            sprintf "Can't find Virtual Voucher SKU ($sku) in %s", $mech->uri );
    }
    my ($container_id) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 } );

    my @ship_items  = $shipment->shipment_items->all;
    foreach my $ship_item ( @ship_items ) {
        my $variant     = $ship_item->get_true_variant;
        my $sku         = $variant->sku;
        if ( !exists $skus->{ $sku } ) {      # if the sku doesn't exists then it should be a virtual voucher
            next if ( $test->{has_virtual_pid} && !$variant->product->is_physical );
            fail( "Got SKU ($sku) which should be in $skus hash but isn't and not a virtual voucher, Shipment Item Id: ".$ship_item->id );
        }

        my $status_log_rs = $ship_item->shipment_item_status_logs
                                      ->search( undef, { order_by => 'id DESC' } );

        $mech->submit_form_ok({
            with_fields => { location => $skus->{$sku}{location} },
            button => 'submit'
        }, sprintf 'Picked shipment item %d (sku %s) from location %s',
            $ship_item->id, $sku, $skus->{$sku}{location}
        );
        $mech->submit_form_ok({
            with_fields => { sku => $sku },
            button => 'submit'
        }, sprintf 'Confirm pick for shipment item %d ( sku %s)', $ship_item->id, $sku
        );
        $mech->submit_form_ok({
            with_fields => { container_id => $container_id->as_barcode },
            button => 'submit'
        }, sprintf 'Picked shipment item %d ( sku %s ) into container %s',
            $ship_item->id, $sku, $container_id->as_barcode
        );

        # Perpertual inventory! - fill it out.
        # The while is here because if the count doesn't match it asks you to count again
        my $perp_count  = 0;
        while ( scalar $mech->find_all_inputs( name=>'input_value' ) ) {
            note sprintf 'in Perp. Inventory loop at uri %s', $mech->uri;
            ++$perp_count;
            $mech->submit_form_ok({
                with_fields => { input_value => 1 },
                button => 'submit'
            }, "Perpertual Inventory for location @{[$skus->{$sku}{location}]} - loop $perp_count");
        }

        $mech->no_feedback_error_ok();

        # check statuses have been picked and logged
        $ship_item->discard_changes;
        $status_log_rs->reset;
        is( $ship_item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__PICKED,
            sprintf(q{Shipment item %d is 'Picked'}, $ship_item->id) );
        is( $status_log_rs->first->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__PICKED,
            sprintf(q{Shipment item %d logged correctly as 'Picked'}, $ship_item->id) );
    }

    $mech->has_feedback_success_ok( qr/The shipment has now been picked/, 'All Items Picked' )
        or diag 'on uri ' . $mech->uri;

    # NOTE: I don't really get this test, we're testing that it hasn't
    # been picked by checking if its status is picked. WTF.

    # test should include a Virtual Voucher that shouldn't have been picked
    if ( $test->{has_virtual_pid} ) {
        foreach my $item ( @ship_items ) {
            $item->discard_changes;
            # this will mean it's the Virtual Voucher Shipment Item
            if ( $item->voucher_variant
                && !$item->voucher_variant->product->is_physical
            ) {
                is( $item->shipment_item_status_id, $SHIPMENT_ITEM_STATUS__PICKED,
                    sprintf('Virtual Voucher in shipment item %d is still picked',
                        $item->id) );
            }
        }
    }
    return;
}

sub test_incomplete_pick {
    my ( $self, $shipment, $skus, $test )  = @_;

    # Test with Operator level access Should NOT see list of Shipments and make test quicker
    Test::XTracker::Data->grant_permissions( 'it.god', 'Fulfilment', 'Picking', $AUTHORISATION_LEVEL__OPERATOR );

    my $mech = $self->{framework}->mech;
    $mech->get_ok( '/Fulfilment/Picking'
                 . ($test->{handheld} ?  '?view=HandHeld' : q{}) );

    my $wms_to_xt = Test::XTracker::Artifacts::RAVNI->new('wms_to_xt');
    $mech->submit_form_ok({
        with_fields => { shipment_id => $shipment->id },
        button => 'submit'
    }, sprintf('Pick shipment %d', $shipment->id) );
    $wms_to_xt->expect_messages( {  messages => [ { type => 'picking_commenced' } ] } );

    $mech->follow_link_ok({ text => 'Incomplete Pick' }, 'declare incomplete pick');

    # we may, in the future, get one other message (an 'inventory_adjust'), but for the moment we only expect one

    $wms_to_xt->expect_messages( {  messages => [ { type => 'incomplete_pick' } ] } );

    ok($shipment->discard_changes->is_on_hold,
        sprintf('shipment %d is on hold', $shipment->id));
    my $hold = $shipment->search_related('shipment_holds',{ },{
        order_by => { -desc => 'hold_date' },
        rows => 1,
    })->single;
    is($hold->shipment_hold_reason_id, $SHIPMENT_HOLD_REASON__INCOMPLETE_PICK, 'correct reason');
    is($hold->operator->username, 'it.god', 'correct operator');
}

1;
