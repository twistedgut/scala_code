#!/usr/bin/env perl

=head1 NAME

returns.t - Test the returns process

=head1 DESCRIPTION

Test returns process:

    * Premier return. Reason: Price
    * Premier return. Reason: Repair
    * Return item, reversal
    * Channel transfer for a PID after we have dispatched a  SKU within that PID
        and then subsequently process an RMA for the SKU which is failed at Returns QC.
    * Create a return. Reason: Exchange. Then cancel the exchange item.
        Verify the exchange item has been cancelled.
    * Create a return. Reason: Exchange. Then cancel the whole return.
        Verify both original item and the exchange item have been cancelled.

#TAGS movetounit intermittentfailure needswork activemq iws prl return goodsin xpath http

=head1 TODO

Get this back in the aggregated Test::Class tests.

DCA-2344: This test wasn't happy when run on jenkins from the aggregate
test class job (intermittent amq monitor problems).

    # Commented out code:
    #package Test::NAP::Returns;

=cut


use NAP::policy "tt", qw/class test/;

BEGIN {
    extends "NAP::Test::Class";
    with 'Test::XT::Data::Order';
}

use Test::XTracker::Data;
use Test::XT::Flow;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::RunCondition( export => [ qw( $iws_rollout_phase $prl_rollout_phase ) ] );

use XTracker::AllocateManager;
use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :customer_issue_type
    :shipment_item_status
    :shipment_status
    :shipment_type
    :flow_status
);

sub startup : Test(startup) {
    my $self = shift;

    $self->SUPER::startup;
    $self->{flow} = Test::XT::Flow->new_with_traits(
        traits => [qw(
            Test::XT::Flow::CustomerCare
            Test::XT::Flow::Fulfilment
            Test::XT::Flow::GoodsIn
            Test::XT::Flow::PrintStation
            Test::XT::Flow::StockControl
            Test::XT::Flow::WMS
        )],
    );
    $self->{channel} = Test::XTracker::Data->channel_for_nap;
}

sub test_premier_return_for_price : Tests {
    my $self = shift;

    $self->_login;
    $self->_return_test_order({
        order => $self->dispatched_order(shipment_type => $SHIPMENT_TYPE__PREMIER)->{order_object},
        reason => $CUSTOMER_ISSUE_TYPE__7__PRICE,
        expect_fail_only => 0,
    });
}

sub test_premier_return_for_repair : Tests {
    my $self = shift;

    $self->_login;
    $self->_return_test_order({
        order => $self->dispatched_order(shipment_type => $SHIPMENT_TYPE__PREMIER)->{order_object},
        reason => $CUSTOMER_ISSUE_TYPE__7__RETURN_FOR_REPAIR,
        expect_fail_only => 1,
    });
}

sub test_return_item_reversal : Tests {
    my $self = shift;

    $self->_login;
    my $return;
    subtest 'create and bookin return' => sub {
        $return = $self->_return_test_order({
            order => $self->dispatched_order->{order_object},
        });
    };

    # Ensure our related rows are as we expect them to be
    my $delivery = $return->deliveries->single;
    my $di = $delivery->delivery_items->single;
    my $sp = $di->stock_processes->single;
    ok( !$delivery->cancel, sprintf 'delivery %d should not be cancelled', $delivery->id );
    ok( !$di->cancel, sprintf 'delivery_item %d should not be cancelled', $di->id );
    ok( !$sp->complete, sprintf 'stock process %d should not be complete', $sp->id );

    my $flow = $self->{flow};
    # Make sure we're in the correct department to do a reversal
    Test::XTracker::Data->set_department( 'it.god', 'Stock Control' );
    $flow->mech__customercare__fetch_return_view( $return->id )
         ->mech__customercare__reverse_booked_in_item
         ->mech__customercare__reverse_booked_in_item_submit( $return->return_items->single->id );

    # Our rows should now be cancelled/completed
    ok( $delivery->discard_changes->cancel, sprintf 'delivery %d should be cancelled', $delivery->id );
    ok( $di->discard_changes->cancel, sprintf 'delivery_item %d should be cancelled', $di->id );
    ok( $sp->discard_changes->complete, sprintf 'stock process %d should be complete', $sp->id );
}

# This tests for a bug where we do a channel transfer for a PID after we have dispatched a
# SKU within that PID and then subsequently process an RMA for the SKU which is failed at
# Returns QC.
sub test_bug_with_channel_transferred_pid_where_returns_qc_failed : Tests {
    my $self = shift;

    # We don't run this when channel transfer is manual since call to
    # task__stock_control__channel_transfer won't work (missing src and dst location). The bug
    # we are testing is independent of auto versus manual channel transfer.
    unless (Test::XTracker::Data->get_enabled_channels->all > 1 &&
            ($iws_rollout_phase || $prl_rollout_phase)) {
        note "Skipping this test -- runs only in multi-channel DCs with IWS or PRLs";
        return;
    }

    $self->_login;
    my $flow = $self->{flow};

    # Create an order
    my $product = (Test::XTracker::Data->grab_products({
        channel_id => $self->{channel}->id,
        force_create => 1,
    }))[1][0]{product};
    my $order = $self->dispatched_order( products => [$product])->{order_object};

    # Transfer the PID in the order to another channel.
    my $mrp_channel = Test::XTracker::Data->channel_for_mrp;
    $flow->task__stock_control__channel_transfer({
        product             => $product,
        channel_from        => $self->{channel},
        channel_to          => $mrp_channel,
        prl_loc             => $prl_rollout_phase ? 'Full PRL' : undef,
    });

    # Log back in with right permissions / department so we can process returns
    $self->_login;

    # Now process the return for the order and fail it in Returns QC
    my $return = $self->_return_test_order({
        order => $order, channel_transferred => 1,
    });
    my $return_item = $return->return_items
                          ->search( {}, { order_by => 'shipment_item_id' } )
                          ->slice(0,0)->single;
    my $variant = $return_item->variant;
    $flow->flow_mech__goodsin__returns_qc__process_item_by_item(
        {
            $return_item->incomplete_stock_process->id =>
                { decision    => 'fail',
                  test_debug_message => 'for SKU: ' . $variant->sku,
                }
        }
    );

    # Go to Returns Faulty, accept the SKU and put it to RTV stock
    $flow->flow_mech__goodsin__returns_faulty;
    my $group_id = $return_item->incomplete_stock_process->group_id;
    $flow->errors_are_fatal(0);
    $flow->flow_mech__goodsin__returns_faulty_submit( $group_id );
    $flow->flow_mech__goodsin__returns_faulty_decision('accept');
    $flow->errors_are_fatal(1);
    $flow->flow_mech__goodsin__returns_faulty_process('return to vendor');

    # Get location to putaway the SKU
    my $location;
    if ( $iws_rollout_phase ){
        ($location) = $flow->data__location__create_new_locations({
            channel_id      => $flow->mech->channel->id,
            allowed_types   => $FLOW_STATUS__RTV_PROCESS__STOCK_STATUS,
        });
    }
    else {
        $flow->data__location__initialise_non_iws_test_locations;
        my $location_rs = $flow->schema->resultset('Public::Location');
        my $putaway_location = $location_rs->get_locations({ floor => 4 })
            ->search_related(
                'location_allowed_statuses',
                {'status_id'=>$FLOW_STATUS__RTV_PROCESS__STOCK_STATUS}
            )
            ->slice(0,0)->single;
        $location = $putaway_location->location->location;
    }

    # Putaway the SKU
    $flow->flow_mech__goodsin__putaway;
    $flow->flow_mech__goodsin__putaway_processgroupid( $group_id);
    $flow->flow_mech__goodsin__putaway_book_submit( $location, 1 );

    # Take care of the stock received message we should have received
    my $monitor = $flow->{wms_receipt_dir};
    $monitor->expect_messages({ messages => [{type => 'stock_received' }]})
        if $monitor;

    # Make sure the SKU was putaway into the channel for the order and not the one
    # we transferred to.
    my $quantity = $flow->schema->resultset('Public::Quantity')->search(
                       {
                           variant_id => $variant->id,
                           quantity => 1,
                           location => $location,
                       },
                       {
                           join => 'location',
                       }
                   )->slice(0,0)->single;
    is( $quantity->channel_id, $self->{channel}->id, 'quantity updated in original channel' );
}

=head2 test_returns_faulty_duplicate_submission

This test will check for duplicate tab submissions on the returns faulty page.

It sets up its data for each of the following scenarios by creating an order is
dispatched, returned, failed at returns QC and then goes to the returns faulty
page.

It then opens a new tab, on the same page, and submits the first action. It
then submits the second action and checks that it fails. Then it closes the tab
and opens a new tab on the second step of returns faulty. It submits the
original tab, which should succeed, then it submits the second tab and checks
that it fails.

The first actions are:

=over

=item Accept

=item Reject

=item RTV Repair

Any reason. RTV Repair isn't followed up by a second action, so no second
action is tested.

=back

The second actions are:

=over

=item Return to Stock

=item Return to Vendor

Any reason

=item Return to Customer

=item Dead Stock

=back

=cut

sub test_returns_faulty_duplicate_submission : Tests {
    my $self = shift;

    my $product = (Test::XTracker::Data->grab_products({
        force_create => 1,
    }))[1][0]{product};

    $self->_login;

    for my $first_action ( qw/accept reject rtv_repair/ ) {
        for my $second_action ( qw/rts rtv rtc dead/ ) {
            subtest "testing $first_action and $second_action" => sub {
                $self->_returns_faulty_duplicate_submission(
                    $product, $first_action, $second_action
                );
            };
        }
    }
}

sub _returns_faulty_duplicate_submission {
    my ( $self, $product, $first_action, $second_action ) = @_;

    my $flow = $self->{flow};

    my $order = $self->dispatched_order( products => [$product])->{order_object};
    my $return = $self->_return_test_order({ order => $order });
    my $return_item = $return->return_items
                        ->search( {}, { order_by => 'shipment_item_id' } )
                        ->slice(0,0)->single;

    # Login in the caller, saves us time if we run this in a loop
    $flow->flow_mech__goodsin__returns_qc__process_item_by_item({
        $return_item->incomplete_stock_process->id => { decision => 'fail' }
    });

    my $group_id = $return_item->incomplete_stock_process->group_id;
    $flow->flow_mech__goodsin__returns_faulty;
    $flow->flow_mech__goodsin__returns_faulty_submit( $group_id );

    my $other_tab = 'other_tab';

    # Open a new tab to test the the duplicate submission
    $flow->open_tab($other_tab);

    # Perform $first_action in the first tab
    $flow->switch_tab('Default');
    $flow->flow_mech__goodsin__returns_faulty_decision($first_action);

    # Test for the failure message in the second tab
    $flow->switch_tab($other_tab);
    $flow->catch_error(
        qr{This item can't be processed as it's in an incorrect state},
        "Submitting an item's first step twice should error",
        flow_mech__goodsin__returns_faulty_decision => $first_action,
    );
    $flow->close_tab;

    # rtv_repair redirects back to return faulty's landing page, it has no
    # second action - so we skip the rest of the test
    return if $first_action eq 'rtv_repair';

    # Open a new tab to test duplicate submission in return faulty's second
    # step
    $flow->open_tab($other_tab);

    # Submit the first tab
    $flow->switch_tab('Default');
    $flow->flow_mech__goodsin__returns_faulty_process($second_action);

    # Expect an error when submitting the second tab
    $flow->switch_tab($other_tab);
    # On failure we redirect to the item's return faulty page, which has its
    # own error message as it's already been processed - so we actually get two
    # error messages here and therefore need to check our error message with a
    # regexp
    $flow->catch_error(
        qr{This item can't be processed as it's in an incorrect state},
        "Submitting an item's second step twice should error",
        flow_mech__goodsin__returns_faulty_process => $second_action,
    );
    $flow->close_tab;
}

sub _login {
    my $self = shift;

    $self->{flow}->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Customer Care/Order Search',
                'Customer Care/Customer Search',
                'Fulfilment/Selection',
                'Fulfilment/Picking',
                'Fulfilment/Packing',
                'Fulfilment/Airwaybill',
                'Fulfilment/Dispatch',
                'Goods In/Returns In',
                'Goods In/Returns QC',
                'Goods In/Returns Faulty',
                'Goods In/Putaway',
            ],
        },
        dept => 'Shipping',
    });
}

sub _return_test_order {
    my $self = shift;
    my $args = shift;

    my $flow = $self->{flow};
    my $order = $args->{order};
    my $schema = $flow->schema;

    # TODO ensure order is not on credit hold (is this needed?)

    # find skus in the order

    my $shipment = $order->shipments->slice(0,0)->first;
    my @variants = $shipment->shipment_items->search_related('variant')->all;
    my @skus = map { $_->sku } @variants;

    # create return for this order
    $flow->task_mech__customercare__create_return( $order->id,
        [map { +{ sku => $_, customer_issue_type_id => $args->{reason} } } @skus]
    );

    # Goods In/Returns Arrival doesn't apply to premier orders

    # Set Goods In/Returns In printer station
    $flow->flow_mech__select_printer_station({
        section => 'GoodsIn',
        subsection => 'ReturnsIn',
        channel_id => $self->{channel}->id,
    });
    $flow->flow_mech__select_printer_station_submit;

    # Book in the SKUS in the shipment
    $flow->task__goodsin__returns_in( $shipment->id, [@skus] );

    # Get allocated RMA number
    my $return = $shipment->returns->slice(0,0)->single;

    # Set Goods In/Returns QC printer station
    $flow->flow_mech__select_printer_station({
            section => 'GoodsIn',
            subsection => 'ReturnsQC',
            channel_id => $self->{channel}->id,
        });
    $flow->flow_mech__select_printer_station_submit;

    # Return is now booked in - visit Returns QC
    $flow->flow_mech__goodsin__returns_qc;
    # We need to allow the 'Transferred to channel_name' message, which isn't an error if
    # we've done a channel transfer.
    $flow->errors_are_fatal(0) if $args->{channel_transferred};
    $flow->flow_mech__goodsin__returns_qc_submit( $return->rma_number );
    $flow->errors_are_fatal(1);

    # See if we have expected QC pass/fail buttons
    my $mech = $flow->mech;
    for my $return_item ($return->return_items->all) {
        # determine stock process id for return_item
        my $sp_id = $return_item->uncancelled_delivery_item->stock_processes->first->id;

        # locate the row for this return item
        my $row_xpath = "//table[\@id='return_items']//tr[\@id='stock_process_$sp_id']";
        ok $mech->find_xpath($row_xpath), "should find return items table row for item number $sp_id";

        # should always have fail button
        ok $mech->find_xpath("$row_xpath//td//input[\@type='radio' and \@name='qc_$sp_id' and \@value='fail' and not(\@disabled)]"),
            "should have enabled fail button for item number $sp_id";

        # Only test this bit if we explicitly pass this key
        next unless defined $args->{expect_fail_only};

        # pass button will depend on return reason
        if ($args->{expect_fail_only}) {
            # should have disabled pass button
            ok $mech->find_xpath("$row_xpath//td//input[\@type='radio' and \@name='qc_$sp_id' and \@value='pass' and \@disabled]"),
                "should have disabled pass button for item number $sp_id";
        }
        else {
            # should have normal pass button
            ok $mech->find_xpath("$row_xpath//td//input[\@type='radio' and \@name='qc_$sp_id' and \@value='pass' and not(\@disabled)]"),
                "should have enabled pass button for item number $sp_id";
        }
    }
    return $return;
}

sub test_cancel_exchange_shipment_item : Tests {
    my $self = shift;

    unless ( $iws_rollout_phase ) {
        SKIP: {
            skip 'This test is only meant to run with IWS', 1;
            ok 1;
        }
        return;
    }

    my $flow = $self->{flow};
    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Customer Care/Order Search',
            'Goods In/Returns In',
            'Goods In/Returns QC',
            'Goods In/Putaway',
            'Fulfilment/Selection',
            'Fulfilment/Picking',
            'Fulfilment/Packing',
            'Fulfilment/Airwaybill',
            'Fulfilment/Dispatch',

        ]},
        dept => 'Customer Care'
    });


    my $mech = $flow->mech;
    $mech->force_datalite(1);

    my $channel_id  = $flow->schema->resultset('Public::Channel')->search({
        'business.config_section' => 'NAP',
    }, {
        join => 'business',
    })->first->id;
    my @products = Test::XTracker::Data->create_test_products({
        channel_id => $channel_id,
        how_many   => 2,
    }); # @products is unused, the DB rows are picked up below
    my ($channel, $variants) = Test::XTracker::Data->grab_multi_variant_product({
            ensure_stock => 1,
            live         => 1
        });
    my @test_variants = ($variants->[0], $variants->[1]);

    my ($order) = Test::XTracker::Data->create_db_order({
            pids => \@test_variants,
            attrs => [
                { price => 100.00 },
                { price => 100.00 },
            ],
        });

    my $shipment_test = $order->shipments->first;
    $mech->order_nr($order->order_nr);
    $mech->test_create_rma($shipment_test, 'exchange',undef,1);

    my $return = $shipment_test->discard_changes->returns->first;

    $mech->test_add_rma_items($return, 'exchange',1);

    #release exchange as distribution management
    $flow->login_with_permissions({
            dept => 'Distribution Management',
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                    'Fulfilment/Selection',
                    'Customer Care/Order Search',
                    'Customer Care/Customer Search',
        ]}
    });

    my $exchange = $return->exchange_shipment;
    $flow->flow_mech__customercare__orderview( $order->id );
    my $button_xpath    = '//form[starts-with(@id,"releaseExchange")]';
    my $node   = $flow->mech->find_xpath( $button_xpath )->get_node;
    ok( ref( $node ), "CAN See Button" );
    $flow->flow_mech__customercare__release_exchange_shipment( $exchange->id );

    $flow->task__selection($exchange);

    my $return_item_first = $return->return_items->not_cancelled->first;

    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    $mech->test_remove_rma_items($return_item_first);
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'shipment_request',
                'details' => { 'shipment_id' => "s-".$exchange->id, },
            },
        ]
    });
}

sub test_cancel_return_with_exchange : Tests {
    my $self = shift;

    my $flow = $self->{flow};

    $flow->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Customer Care/Customer Search',
        ]},
        dept => 'Customer Care'
    });

    $flow->mech->force_datalite(1);

    my $shipment;
    subtest 'create dispatched shipment' => sub {
        $shipment = $self->dispatched_order->{shipment_object};
    };

    my $exchange;
    subtest 'create an exchange shipment' => sub {
        {
        my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
        $flow->task_mech__customercare__create_return($shipment->order->id, [{
            return_type => 'Exchange',
            sku => $shipment->shipment_items
                            ->related_resultset('variant')
                            ->slice(0,0)
                            ->single
                            ->sku,
        }]);
        $xt_to_prls->expect_messages({ messages => [{ type => 'allocate' }] })
            if $prl_rollout_phase;
        $xt_to_prls->new_files;
        }

        # Make sure the exchange is on return hold
        $exchange = $shipment->returns->related_resultset('exchange_shipment')->slice(0,0)->single;
        ok( $exchange, 'create exchange shipment ' . $exchange->id );
        ok( $exchange->is_on_return_hold, 'exchange shipment is on return hold' )
            or die 'exchange shipment has status of ' . $exchange->shipment_status->status;

        # Have to use allocate_response here - I tried to use
        # Test::XT::Data::Order::allocate_to_shipment but it does nothing if
        # the allocations are already requested :/
        if ( $prl_rollout_phase ) {
            my $allocation = $exchange->allocations->single;
            my $allocation_item = $allocation->allocation_items->single;
            XTracker::AllocateManager->allocate_response({
                allocation => $allocation,
                allocation_items => [$allocation_item],
                sku_data => {
                    $allocation_item->variant_or_voucher_variant->sku => {
                        allocated => 1,
                        short     => 0,
                    },
                },
                operator_id => $APPLICATION_OPERATOR_ID,
            });
        }
    };

    subtest 'release and pick exchange shipment' => sub {
        # We need to be in distribution management to release an exchange shipment
        # manually
        $flow->login_with_permissions({
            dept => 'Distribution Management',
            perms => { $AUTHORISATION_LEVEL__MANAGER => [
                'Customer Care/Customer Search',
                'Fulfilment/Selection',
                'Fulfilment/Picking',
            ]}
        });

        $flow->flow_mech__customercare__orderview( $shipment->order->id );
        $flow->flow_mech__customercare__release_exchange_shipment($exchange->id);

        # Make sure we sent a message to pick the shipment if we're have PRLs
        {
        my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
        $flow->task__selection($exchange);
        $xt_to_prls->expect_messages({
            messages => [{
                type => 'pick',
                details => {
                    allocation_id => $exchange->allocations->slice(0,0)->single->id,
                },
            }]
        }) if $prl_rollout_phase;
        $xt_to_prls->new_files;
        }
        $flow->task__picking($exchange);
    };

    # Cancel return item (and the exchange shipment by association)
    $flow->flow_mech__customercare__orderview( $shipment->order->id );
    $flow->flow_mech__customercare__click_on_rma( $exchange->exchange_return->rma_number );
    $flow->mech__customercare__link_to_cancel_return;

    # Check we can cancel the shipment and the appropriate messages are (or
    # aren't) being sent
    {
    my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');
    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    $flow->mech__customercare__cancel_return_submit;
    $flow->mech->has_feedback_success_ok('Return cancelled successfully.');
    $xt_to_prls->expect_no_messages if $prl_rollout_phase;
    if ( $prl_rollout_phase ) {
        $xt_to_wms->expect_no_messages;
    }
    else {
        $xt_to_wms->expect_messages({
            messages => [ {
                type    => 'shipment_cancel',
                details => { shipment_id => 's-' . $exchange->id },
            } ]
        });
    }
    $xt_to_prls->new_files;
    }
}

Test::Class->runtests;
