#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

messages.t - Test messages sent from the Quality Control screen

=head1 DESCRIPTION

Create a purchase order for a quantity of 40, and step through the Stock In and
Item Count pages (having counted 60 items), verify no messages so far.

Mark some items as faulty, verify two I<pre_advice> messages are sent, one for
I<main> and the other for I<faulty> items.

Verify three documents are generated.

Go to the Goods In/Surplus page for the surplus PGID, submit some as I<rtv> and
some as I<accepted>, and verify we have sent the messages.

If we're in phase 0, send a stock_received message to XTracker and verify we
have 10 new items with a status of I<RTV Goods In>.

#TAGS iws checkruncondition duplication goodsin stockin itemcount qualitycontrol rtv whm

=cut

use FindBin::libs;


use Test::More::Prefix qw( test_prefix );
use Test::Differences;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :stock_order_status
);
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::PrintDocs;
use Test::XTracker::LocationMigration;
use XTracker::Config::Local qw( config_var );
use Data::Dump qw(pp);

use Test::XTracker::RunCondition dc => 'DC1', export => qw( $iws_rollout_phase );


my $perms = {
    $AUTHORISATION_LEVEL__OPERATOR => [
        'Goods In/Stock In',
        'Goods In/Item Count',
        'Goods In/Surplus',
        'Goods In/Quality Control',
        'Goods In/Bag And Tag',
    ],
};

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Data::Location',
        'Test::XT::Feature::AppMessages',
        'Test::XT::Flow::GoodsIn',
        'Test::XT::Flow::PrintStation',
        'Test::XT::Flow::StockControl',
        'Test::XT::Flow::WMS',
    ],
);
$flow->force_datalite(1);

run_tests();

done_testing;

sub run_tests{

    note 'Clearing all test locations';
    $flow->data__location__destroy_test_locations;

    my $purchase_order = Test::XTracker::Data->create_from_hash({
        channel_id      => $flow->mech->channel->id,
        placed_by       => 'Ian Docherty',
        confirmed       => 1,
        stock_order     => [{
            status_id       => $STOCK_ORDER_STATUS__ON_ORDER,
            product         => {
                product_type_id => 6,
                style_number    => 'ICD STYLE',
                variant         => [{
                    size_id         => 1,
                    stock_order_item    => {
                        quantity            => 40,
                    },
                }],
                product_channel => [{
                    channel_id      => $flow->mech->channel->id,
                }],
                product_attribute => {
                    description     => 'New Now Know How',
                },
                price_purchase => {},
            },
        }],
    });

    my $location = $flow->data__location__create_new_locations({
        quantity    => 1,
        channel_id  => $flow->mech->channel->id,
    })->[0];
    note 'Created location ['. $location .']';

    # Set up the msg directory reader.
    my $msg_dir_ravni = Test::XTracker::Artifacts::RAVNI->new('xt_to_wms');

    # only one stock_order and stock_order_item in purchase order
    my $stock_order = $purchase_order->stock_orders->first;
    my $variant     = $stock_order->stock_order_items->first->variant;
    my $quantity    = $stock_order->stock_order_items->first->quantity;
    my $sku         = $variant->sku;
    my $product_id  = $variant->product_id;

    # Kick everything off by logging in
    $flow
        ->inline_force_datalite(1)
        ->login_with_permissions({
            dept => 'Distribution Management',
            perms => $perms,
        });

    # Enter the packing slip values
    $flow->task__set_printer_station(qw/GoodsIn StockIn/);
    $flow
        ->flow_mech__goodsin__stockin_packingslip( $stock_order->id )
        ->flow_mech__goodsin__stockin_packingslip__submit({ $sku => $quantity });

    $flow->task__set_printer_station(qw/GoodsIn ItemCount/);

    # Item count
    my $delivery_id = $stock_order->deliveries->first->id;
    $flow
        ->flow_mech__goodsin__itemcount_deliveryid( $delivery_id )
        ->flow_mech__goodsin__itemcount_submit_counts({
            counts => { $sku => 60 },
            weight  => '1.5',
        });

    # We should have no msgs appeared so far
    is_deeply( [ $msg_dir_ravni->new_files ], [], "No new messages received" );
    # Set up the print dir so we can get the PGIDs...
    my $print_directory = Test::XTracker::PrintDocs->new();

    $flow->task__set_printer_station(qw/GoodsIn QualityControl/);

    # Quality Control
    if ($iws_rollout_phase == 0) {
        $flow
            ->flow_mech__goodsin__qualitycontrol_deliveryid( $delivery_id )
            ->flow_mech__goodsin__qualitycontrol_processitem_submit( {
                qc => {
                    'weight' => '0.23',
                    'length' => 2,
                    'width'  => 2,
                    'height' => 2,
                    'faulty_container' =>
                        (Test::XT::Data::Container->get_unique_ids( { how_many => 1 } ))[0],
                    $sku => { checked => 60, faulty => 10 }
                }
            });
        $msg_dir_ravni->expect_messages({
            messages => [
                { type => 'pre_advice',
                  details => { items => [ { skus => [ { sku => $sku, quantity => 40 } ] } ],
                               stock_status => 'main'
                             }
                },
                { type => 'pre_advice',
                  details => { items => [ { skus => [ { sku => $sku, quantity => 10 } ] } ],
                               stock_status => 'faulty'
                             }
                }
            ]
        });
    }
    else {
        $flow
            ->flow_mech__goodsin__qualitycontrol_deliveryid( $delivery_id )
            ->flow_mech__goodsin__qualitycontrol_processitem_submit( {
                qc => {
                    'weight' => '0.23',
                    'length' => 2,
                    'width'  => 2,
                    'height' => 2,
                    $sku => { checked => 60, faulty => 10 }
                }
            });
        # We should have sent one message saying we have 40 good stock
        # -- faulty items should not result in a pre-advice in phase 1+

        $msg_dir_ravni->expect_messages({
            messages => [
                { type => 'pre_advice',
                  details => { items => [ { skus => [ { sku => $sku, quantity => 40 } ] } ],
                               stock_status => 'main'
                             }
                }
            ],
            unexpected => [
                { type => 'pre_advice',
                  details => { items => [ { skus => [ { sku => $sku, quantity => 10 } ] } ],
                               stock_status => 'faulty'
                             }
                }
            ]
        });
    }

    # Crack out the PGID for the surplus
    my %pgids = map { $_->file_type => $_->file_id }
        $print_directory->wait_for_new_files( files => 3 );
    undef $print_directory; # Tear this down now so we don't get an unhandled files warning

    note "Surplus PG-ID: [$pgids{'surplus'}]";

    # Let's chase down the surplus
    $flow->task__set_printer_station(qw/GoodsIn Surplus/);
    $flow
        ->flow_mech__goodsin__surplus_processgroupid( $pgids{'surplus'} )
        ->flow_mech__goodsin__surplus_processgroupid_submit({
            $sku => {
                accepted => 7,
                rtv      => 3,
            }
        });


    if ($iws_rollout_phase == 0) {
        $msg_dir_ravni->expect_messages({
            messages => [
                { type => 'pre_advice',
                  details => { items => [ { skus => [ { sku => $sku, quantity => 7 } ] } ],
                               stock_status => 'main'
                             }
                },
                { type => 'pre_advice',
                  details => { items => [ { skus => [ { sku => $sku, quantity => 3 } ] } ],
                               stock_status => 'rtv'
                             }
                }
            ]
        });

        # Snapshot it in the DB
        my $db_state = Test::XTracker::LocationMigration->new( variant_id => $variant->id );
        $db_state->snapshot('Before');

        # Send message to XTracker and wait...
        my $completed_sp_rs = $flow->schema->resultset('Public::StockProcess')
            ->get_group($pgids{'faulty'});

        # Pretend INVAR has done the putaway for our faulty stock...
        $flow->wms__send_stock_received(sp_group_rs => $completed_sp_rs);

        # Snapshot it in the DB, check it's incremented by 10
        $db_state->snapshot('After');
        $db_state->test_delta(
            from => 'Before',
            to   => 'After',
            stock_status => { 'RTV Goods In' => +10 }
        );
    }
    else {
        $msg_dir_ravni->expect_messages({
            messages => [
                { type => 'pre_advice',
                  details => { items => [ { skus => [ { sku => $sku, quantity => 7 } ] } ],
                               stock_status => 'main'
                             }
                }
            ],
            unexpected => [
                { type => 'pre_advice',
                  details => { items => [ { skus => [ { sku => $sku, quantity => 3 } ] } ],
                               stock_status => 'rtv'
                             }
                }
            ]
        });
    }
}


sub test_messages {
    my ( $test_messages, $reference_messages, $test_name ) = @_;

    # Do we have the right number of messages?
    is( scalar(@$test_messages), scalar(@$reference_messages),
        "$test_name: correct number of messages found" );

    my $sort = sub {
        $a->{'type'}         cmp $b->{'type'} ||
        $a->{'sku'}          cmp $b->{'sku'}  ||
        $a->{'stock_status'} cmp $b->{'stock_status'} ||
        $a->{'quantity'}     cmp $b->{'quantity'}
    };

    # Map what we actually got to the reference
    $test_messages = [
        sort $sort map {
            my $old = $_->payload_parsed;
            my $new = {};
            $new->{'sku'}      = $old->{'items'}->[0]->{'skus'}->[0]->{'sku'};
            $new->{'quantity'} = $old->{'items'}->[0]->{'skus'}->[0]->{'quantity'};
            $new->{'stock_status'} = $old->{'stock_status'};
            $new->{'type'}         = $old->{'@type'};
            $new;
        } @$test_messages
    ];

    # Sort the reference messages too
    $reference_messages = [ sort $sort @$reference_messages ];

    # Check
    eq_or_diff( $test_messages, $reference_messages,
        $test_name . ": messages match");
}

