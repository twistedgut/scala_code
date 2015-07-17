#!/usr/bin/env perl

=head1 NAME

shipment_changes_mid-pick_dirty.t - When a shipment changes during picking

=head1 DESCRIPTION

Test to ensure we can handle shipment_ready messages when the shipment is not
ready. Should also ensure that shipments changed between shipment_ready and
packing also behave well.

Run through twice doing things in slightly different order:

    - create an order (selected) with multiple items
    - exchange one item for another
    - send shipment_ready for original order
    - ensure we send off_hold message to IWS
    - ensure sensible message is displayed to packer
    - send shipment to PE

    first pass:
        - pick final item and send another shipment_ready
        * send second tote to PE
        - ensure totes can be sorted and reconciled at PE
        - ensure packer can now pack shipment
    second pass:
        - ensure totes can be sorted and reconciled at PE
        - pick final item and send another shipment_ready
        * Ensure that all shipment items are picked or remain cancelled
        - ensure packer can now pack shipment

#TAGS fulfilment packing packingexception checkruncondition iws whm

=head1 SEE ALSO

shipment_changes_mid-pick_clean.t

=cut

use NAP::policy "tt", 'test';

# The shipment_ready message is specific to IWS
use Test::XTracker::RunCondition iws_phase => 'iws', dc => 'DC1';


use Test::More::Prefix qw/test_prefix/;
use Test::Differences;
use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB qw(:authorisation_level);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

# Start-up gubbins here. Test plan follows later in the code...
test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
        'Test::XT::Feature::AppMessages',
        'Test::XT::Data::Location',
        'Test::XT::Flow::WMS',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Selection'
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);
my $xt_to_wms = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

my ($channel,$pids,$order_data,$shipment_id,@container_ids);
# grab_multi_variant_product does not create products if they're not there…
# grab_products does. I'm too lazy to change the rest of the code
($channel)=Test::XTracker::Data->grab_products({
    how_many => 2,
    how_many_variants => 2,
    ensure_stock_all_variants => 1,
    force_create => 1, # true
});

# NOTE - container list
# 0 : original pick tote
# 1 : second pick tote
# 2 : 1st good item scanned here
# 3 : cancelled item scanned here
# 4 : 2nd good item scanned here

#####################

test_prefix("First Pass");
note "second tote arrives before PE complete";
place_order();
first_shipment_ready();
first_tote_arrives_at_packer();
second_shipment_ready([ [ $pids->[0]->{sku} => 'Picked' ],
                        [ $pids->[1]->{sku} => 'Cancel Pending' ],
                        [ $pids->[2]->{sku} => 'Picked' ], ]);
second_tote_at_packer_before_pe();
handle_shipment_at_packing_exception([ [ $pids->[0]->{sku} => 'Picked' ],
                                       [ $pids->[1]->{sku} => 'Cancelled' ],
                                       [ $pids->[2]->{sku} => 'Picked' ],
                                     ]);
start_successful_pack("$container_ids[2], $container_ids[4]");

#####################

test_prefix("Second Pass");
note "second tote arrives after PE complete";
place_order();
first_shipment_ready();
first_tote_arrives_at_packer();
handle_shipment_at_packing_exception([ [ $pids->[0]->{sku} => 'Picked' ],
                                       [ $pids->[1]->{sku} => 'Cancelled' ],
                                       [ $pids->[2]->{sku} => 'Selected' ],
                                     ]);
second_shipment_ready([ [ $pids->[0]->{sku} => 'Picked' ],
                        [ $pids->[1]->{sku} => 'Cancelled' ],
                        [ $pids->[2]->{sku} => 'Picked' ], ]);
start_successful_pack("$container_ids[1], $container_ids[2]");

#####################


done_testing();


sub place_order {
    # create and pick the order
    test_prefix("Setup: order shipment");
    (undef,$pids) = Test::XTracker::Data->grab_products({
        channel => $channel,
        how_many => 1,
    });
    my (undef, $variants) =
        Test::XTracker::Data->grab_multi_variant_product({
            channel => $channel,
            ensure_stock => 1
        });
    $pids = [@$pids, @$variants]; # splice them together

    $order_data = $framework->flow_db__fulfilment__create_order_selected( channel  => $channel, products => [ $pids->[0], $pids->[1] ], );
    $shipment_id = $order_data->{'shipment_id'};
    note "shipment $shipment_id created";

    note "exchange an item from the order";
    $framework
        ->flow_mech__customercare__orderview( $order_data->{'order_object'}->id )
        ->flow_mech__customercare__size_change()
        ->flow_mech__customercare__size_change_submit( [ $pids->[1]->{sku} => $pids->[2]->{sku} ] )
        ->flow_mech__customercare__size_change_email_submit
        # is the shipment in a sensible state
        ->flow_mech__customercare__orderview_status_check(
            $order_data->{'order_object'}->id,
            [
                [ $pids->[0]->{sku} => 'Selected' ],
                [ $pids->[1]->{sku} => 'Cancelled' ],
                [ $pids->[2]->{sku} => 'Selected' ],
            ], "Items match before first shipment_ready" );

    # clear iws dir
    $xt_to_wms->new_files;
}

sub first_shipment_ready {
    # fake a shipment_ready message for original order
    test_prefix("Test shipment_ready effects");
    $framework->flow_wms__send_picking_commenced( $order_data->{shipment_object} );
    @container_ids = Test::XT::Data::Container->get_unique_ids( { how_many => 5 } );
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipment_id,
        container => {
            $container_ids[0] => [ $pids->[0]->{sku}, $pids->[1]->{sku} ],
        },
    );

    # is the shipment in a sensible state
    $framework->flow_mech__customercare__orderview_status_check(
        $order_data->{'order_object'}->id,
        [
            [ $pids->[0]->{sku} => 'Picked' ],
            [ $pids->[1]->{sku} => 'Cancel Pending' ],
            [ $pids->[2]->{sku} => 'Selected' ],
        ], "Items match after first shipment_ready" );

    # have we sent unpause message (to instruct IWS to get other item)
    $xt_to_wms->expect_messages({
        messages => [{
            '@type'   => 'shipment_wms_pause',
            'details' => { 'shipment_id' => "s-$shipment_id",
                           'pause'       => 0 },
        }]
    });
}

sub first_tote_arrives_at_packer {
    test_prefix("First tote arrives at packer");
    $framework->flow_mech__fulfilment__packing;
    $framework->errors_are_fatal(0);
    $framework->flow_mech__fulfilment__packing_submit( $container_ids[0] );
    like ($framework->mech->app_error_message,
          qr{The shipment \d+ is not ready to be packed\b},
          "Item still needs to be picked.");
    $framework->errors_are_fatal(1);


    # PIPE and PIPEO stuff
    test_prefix("put good item in tote to PE");
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pids->[0]->{'sku'} )
              ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $container_ids[2] )
              ->flow_mech__fulfilment__packing_placeinpetote_mark_complete
              ->flow_mech__fulfilment__packing_emptytote_submit('no');
    test_prefix("Put cancelled item in tote to PE");
    like($framework->mech->app_info_message,
         qr{Please scan unexpected item},
         'packer asked to send shipment to exception desk');
    $framework->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item($pids->[1]->{sku})
              ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote($container_ids[3])
              ->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete;
    # check we sent shipment_received, item_moved message and shipment_reject
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'shipment_received',
                'details' => { 'shipment_id' => "s-$shipment_id", },
            },
            {
                '@type'   => 'shipment_reject',
                'details' => { 'shipment_id' => "s-$shipment_id",
                               'containers' => [{container_id => $container_ids[2],
                                                 items => [{ sku => $pids->[0]->{'sku'},
                                                             quantity => 1 }],
                                               }]
                             },
            },
            {
                '@type'   => 'item_moved',
                'details' => { 'shipment_id' => "s-$shipment_id",
                               'from'  => {container_id => $container_ids[0]},
                               'to'    => {container_id => $container_ids[3]},
                               'items' => [{sku => $pids->[1]->{sku},
                                            quantity => 1,}],
                             },
            },
        ]
    });
}

sub second_shipment_ready {
    my $expected_status = shift;
    ##################
    # get full shipment_ready message
    test_prefix("Receive second shipment_ready message");
    # at some point later we get another shipment_ready message
    $framework->flow_wms__send_shipment_ready(
        shipment_id => $shipment_id,
        container => {
            $container_ids[2] => [ $pids->[0]->{sku} ],
            $container_ids[1] => [ $pids->[2]->{sku} ],
        },
    );

    $framework->flow_mech__customercare__orderview_status_check(
        $order_data->{'order_object'}->id, $expected_status, "Items match after second shipment_ready"
    );


    # we should not be unpausing now
    $xt_to_wms->expect_messages({
        seconds => 5,
        unexpected => [{
            '@type'   => 'shipment_wms_pause',
            'details' => { 'shipment_id' => "s-$shipment_id" },
        }]
    });
}

sub second_tote_at_packer_before_pe {
    ##################
    # second tote arrives at packer before PE
    $xt_to_wms->new_files;
    test_prefix("Second tote arrives at packer");
    $framework->flow_mech__fulfilment__packing;
    $framework->errors_are_fatal(0);
    $framework->flow_mech__fulfilment__packing_submit( $container_ids[1] );
    like ($framework->mech->app_error_message,
          qr{Please continue scanning item\(s\) into new tote\(s\) and send to the packing exception desk},
          "Need to send to PE to complete.");
    $framework->errors_are_fatal(1);
    ##################
    # PIPE stuff
    test_prefix("put final good item in tote to PE");
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pids->[2]->{'sku'} )
              ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $container_ids[4] )
              ->flow_mech__fulfilment__packing_placeinpetote_mark_complete;
    # check we sent shipment_reject
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'shipment_reject',
                'details' => { 'shipment_id' => "s-$shipment_id",
                               'containers' => [{container_id => $container_ids[2],
                                                 items => [{ sku => $pids->[0]->{'sku'},
                                                             quantity => 1 }],
                                                },
                                                {container_id => $container_ids[4],
                                                 items => [{ sku => $pids->[2]->{'sku'},
                                                             quantity => 1 }],
                                                }]
                             },
            },
        ]
    });
}

sub handle_shipment_at_packing_exception {
    my $expected_status = shift;
    #################
    # Deal at packing exception

    # We need the shipment item id for $pids->[1] for the next actiojn
    my ($p1si) = grep { $_->get_sku eq $pids->[1]->{'sku'} }
            $order_data->{shipment_object}->shipment_items->all;

    # Putaway tote
    my ($tote) = Test::XT::Data::Container->get_unique_ids({ how_many => 1 });


    test_prefix("check we can sort it at packing exception");
    $framework->flow_mech__fulfilment__packingexception
              ->flow_mech__fulfilment__packingexception_submit( $shipment_id )
              ->flow_mech__fulfilment__packingexception_shipment_item_mark_putaway( $p1si->id )
              ->flow_mech__fulfilment__packing_scanoutpeitem_sku( $pids->[1]->{'sku'} )
              ->task__fulfilment__packing_scanoutpeitem_to_putaway(
                  $tote,
                  $pids->[1]->{'sku'},
              )
                # say we're done
              ->flow_mech__fulfilment__packing_checkshipmentexception_submit();
    # check item statuses
    $framework->flow_mech__customercare__orderview_status_check(
        $order_data->{'order_object'}->id, $expected_status, "Items match after first shipment_ready"
    );
    # check messages
    $xt_to_wms->expect_messages({
        messages => [
            {
                '@type'   => 'item_moved',
                'details' => { 'shipment_id' => "s-$shipment_id",
                               'from'  => {container_id => $container_ids[3]},
                               'to'    => {container_id => $tote },
                               'items' => [{sku => $pids->[1]->{sku},
                                            quantity => 1,}],
                             },
            },
            {
                '@type'   => 'shipment_wms_pause',
                'details' => { 'shipment_id' => "s-$shipment_id",
                               'pause'       => 0 },
            },
        ]
    });
}

sub start_successful_pack {
    my $container_str = shift;
    ################
    # Should be able to pack the shipment as expected now
    test_prefix("Can we pack now please?");
    $framework->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $container_ids[2] )
        ->test_mech__app_info_message__like(
            qr/spread across several totes/,
            "Totes found in DB, user prompted to find them"
        );
}

