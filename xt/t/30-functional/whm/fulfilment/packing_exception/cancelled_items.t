#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

cancelled_items.t - Test cancelling items at packing

=head1 DESCRIPTION

=head2 Setup

Create products P1 to P9. We're going to make sure that P8 contains more than
one variant, as we're going to cancel it by swapping it. We'll put the other
variant in P6.

=head2 Act 1

... in which our hero (T1) contains one shipment (S1) of 4 items (P1..P4), two
of which get failed (P1, P2) at Packing, and two of which (P1, P3) get
cancelled on their way to the Packing Exception desk.

At this point:
    P1 - Cancel-pending item, no faulty/non-faulty status
    P2 - Faulty item
    P3 - Cancel-pending item, no faulty/non-faulty status
    P4 - Just fine

All four items are displayed at Packing Exception. P1 and P3 are marked as
'Cancelled'. The user is prompted to scan them out of the tote. The user must
scan these to what XTracker believes is an empty tote (T2). In Phase 0, this
means no further action beyond the tote dissociation is needed. In Phase 1 and
Phase 2, we cancel the items and update web stock.

=head2 Act 2

BUT THEN! Dastardly T3 appears with one shipment (S2) of 4 items (P5..P8), two
of which get failed (P5, P6) at Packing, and three of which (P5..P7) get
cancelled on their way to the Packing Exception desk, and P8 gets exchanged
for another item (P9). When this tote is scanned it should take you to the
shipment page as normal, you scan out all items to a PutAway tote. You MUST
NOT see P9 on that page.

(Act 2 not implemented?)

#TAGS fulfilment packing packingexception duplication todo whm

=head1 CREDITS

Narrator: Peter Sergeant

=head1 SEE ALSO

cancelled_ph_items.t

=cut

use Data::Dumper;


use Test::Differences;
use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :packing_exception_action
    :shipment_item_status
);
use XTracker::Database qw(:common);
use Test::XT::Data::Container;
use XTracker::Config::Local qw(config_var);

test_prefix('Setup');

# Start-up gubbins here. Test plan follows later in the code...
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Feature::AppMessages',
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare'

    ],
);

$framework->clear_sticky_pages;
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Customer Care/Customer Search',
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Commissioner',
    ]},
    dept => 'Customer Care'
});
$framework->mech->force_datalite(1);

my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 7 });
my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);
my @totes = Test::XT::Data::Container->get_unique_ids( { how_many => 5 } );
my %totes = map {; "T$_" => shift( @totes ) } 1..(scalar @totes);

# We're going to make sure that P8 contains more than one variant, as we're
# going to cancel it by swapping it. We'll put the other variant in P6.
my ($new_channel, $variants) =
    Test::XTracker::Data->grab_multi_variant_product({
        channel => $channel,
        ensure_stock => 1
    });
( $products{'P8'}, $products{'P9'} ) = @$variants;

my %shipments;
$shipments{"S1"} = $framework->flow_db__fulfilment__create_order_picked(
    channel  => $channel,
    products => [ @products{ 'P1' .. 'P4' } ],
    tote_id  => $totes{'T1'}
);
$shipments{"S2"} = $framework->flow_db__fulfilment__create_order_picked(
    channel  => $channel,
    products => [ @products{ 'P5' .. 'P8' } ],
    tote_id  => $totes{'T2'}
);

act1();
done_testing();

sub act1 {
    test_prefix('Act 1 - Setup');

    $framework->mech__fulfilment__set_packing_station( $channel->id );
    # Pack the shipment
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $totes{'T1'} )

    # Fail P1 and P2
        ->catch_error(
            qr/send to the packing exception/,
            "Send to packing exception message issued",
            flow_mech__fulfilment__packing_checkshipment_submit => (
                fail => {
                    sku('P1') => "Has clearly been on fire at some point",
                    sku('P2') => "Muppet fur is the wrong texture"
                }
            )
        );

    # Check the status of the shipment items are as expected
    test_tote_items(
        "Shipment items in correct state after Check Shipment",
        $totes{'T1'},
        [
            [ $products{'P1'} => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [ $products{'P2'} => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [ $products{'P3'} => $SHIPMENT_ITEM_STATUS__PICKED ],
            [ $products{'P4'} => $SHIPMENT_ITEM_STATUS__PICKED ],
        ]
    );

    # We should be in PIPE...
    $framework->assert_location(qr!/Fulfilment/Packing/PlaceInPEtote!);
    for ( 'P1' .. 'P4' ) {
        $framework
            ->flow_mech__fulfilment__packing_placeinpetote_scan_item( sku( $_ ) )
            ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $totes{'T3'} );
    }
    $framework->test_mech__app_info_message__like(qr!to the packing exception desk!);
    $framework->flow_mech__fulfilment__packing_placeinpetote_mark_complete;

    # Cancel P1 and P3
    $framework
        ->flow_mech__customercare__orderview( $shipments{'S1'}->{'order_object'}->id )
        ->flow_mech__customercare__cancel_shipment_item()
        ->flow_mech__customercare__cancel_item_submit(
            sku('P1'), sku('P3')
        )->flow_mech__customercare__cancel_item_email_submit;


    # Check the status of the shipment items are as expected
    test_tote_items(
        "Shipment items in correct state after cancellations",
        $totes{'T3'},
        [
            [ $products{'P1'} => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING    ],
            [ $products{'P2'} => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [ $products{'P3'} => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING    ],
            [ $products{'P4'} => $SHIPMENT_ITEM_STATUS__PICKED            ],
        ]
    );

    # Open the shipment at PE Desk, and check that we see P1 and P3 as
    #   cancelled, P2 as QC fail, and P4 as QC pass
    test_prefix('Act 1 - Tests');
    $framework
        ->flow_mech__fulfilment__packingexception
        ->flow_mech__fulfilment__packingexception_submit( $totes{'T3'} );

    my @shipment_items = @{$framework->mech->as_data->{'shipment_items'}};
    is( scalar @shipment_items, 4, "Four items are shown" );

    # Set up a simple function to return item status from sku from the page

    # Check what's on the page is what we think it should be
    eq_or_diff(
        [ map { [sku($_) => status_by_sku(sku($_), @shipment_items ) ] } 'P1'..'P4' ],
        [
            [sku('P1') => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING    ],
            [sku('P2') => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [sku('P3') => $SHIPMENT_ITEM_STATUS__CANCEL_PENDING    ],
            [sku('P4') => $SHIPMENT_ITEM_STATUS__PICKED            ],
        ],
        "Displayed items are correct"
    );

    # Scan P1 and P3 in to a tote - the tote shouldn't record them in XTracker,
    #   and this only works with 'empty' totes
    for my $pid ('P1', 'P3') {
        $framework
            ->flow_mech__fulfilment__packingexception_shipment_item_mark_putaway(
                sku($pid),
            )
            ->flow_mech__fulfilment__packing_scanoutpeitem_sku( sku($pid) )
            ->task__fulfilment__packing_scanoutpeitem_to_putaway(
                $totes{'T4'},
                sku($pid),
            );
    }

    # Check PE Desk shows P2 as failed, P4 as QC pass
    @shipment_items = @{$framework->mech->as_data->{'shipment_items'}};
    is( scalar @shipment_items, 2, "Two items are shown" );
    eq_or_diff(
        [ map { [sku($_) => status_by_sku(sku($_), @shipment_items ) ] } 'P2','P4' ],
        [
            [sku('P2') => $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION ],
            [sku('P4') => $SHIPMENT_ITEM_STATUS__PICKED            ],
        ],
        "Displayed items are correct"
    );

    # Scan out P2 to a faulty tote
    $framework
        ->flow_mech__fulfilment__packing_checkshipmentexception_faulty( sku('P2') )
        ->flow_mech__fulfilment__packing_scanoutpeitem_sku( sku('P2') )
        ->flow_mech__fulfilment__packing_scanoutpeitem_tote( $totes{'T5'} );

    # Say we're done with the tote
    $framework->flow_mech__fulfilment__packing_checkshipmentexception_submit();

    # Check we logged this packing exception action correctly
    {
    my ($shipment_item) = grep { $_->{SKU} eq sku('P2') } @shipment_items;
    my $faulty_item = $framework->schema
                                ->resultset('Public::ShipmentItem')
                                ->find($shipment_item->{'Shipment Item ID'});
    isa_ok(
        my $si_log = $faulty_item->search_related('shipment_item_status_logs',
            undef, { rows => 1, order_by => { -desc => 'date' }, }
        )->single, 'XTracker::Schema::Result::Public::ShipmentItemStatusLog' );
    is( $si_log->packing_exception_action_id, $PACKING_EXCEPTION_ACTION__FAULTY,
        'packing exception action logged correctly' );
    }

    # Shipment should now show up in the commissioner
    $framework->flow_mech__fulfilment__commissioner();
    my ($found_shipment) =
        grep {
            $_->{'Shipment Number'} eq $shipments{'S1'}->{shipment_id} &&
            $_->{'Container'}       eq $totes{'T3'}
        }
        @{$framework->mech->as_data->{'Ready for Packing'}};

    ok( $found_shipment, "Shipment waiting for replacement in Commissioner" )
        || die Dumper $framework->mech->as_data->{'Ready for Packing'};
}

sub test_tote_items {
    my ( $test_name, $tote_id, $items ) = @_;

    # Map actual items to their variant ID
    my @v_items = sort { $a->[0] <=> $b->[0] } map {
        my ( $pid, $status ) = @$_;
        [ $pid->{'variant_id'}, $status ]
    } @$items;

    # Get the data straight from the DB
    my @db_items =
        sort { $a->[0] <=> $b->[0] }
        map {
            [ $_->variant_id, $_->shipment_item_status_id ];
        } Test::XTracker::Data->get_schema()
            ->resultset('Public::ShipmentItem')->search({
                container_id => $tote_id
            });

    eq_or_diff( \@db_items, \@v_items, $test_name );
}

sub status_by_sku {
    my ($desired, @shipment_items) = @_;
    my ($item) = grep { $_->{'SKU'} eq $desired } @shipment_items;
    ok( $item, "SKU $desired found" );
    if ( $item->{'Actions'} &&
        $item->{'Actions'} =~ m/This item has been cancelled/ ) {
        return $SHIPMENT_ITEM_STATUS__CANCEL_PENDING;
    } elsif ( $item->{'QC'} ne 'Ok' ) {
        return $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION;
    } else {
        return $SHIPMENT_ITEM_STATUS__PICKED;
    }
}

sub sku { return $products{shift()}->{'sku'} };

__DATA__
