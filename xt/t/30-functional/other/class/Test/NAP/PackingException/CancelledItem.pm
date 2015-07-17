package Test::NAP::PackingException::CancelledItem;

=head1 NAME

Test::NAP::PackingException::CancelledItem - Test that cancelled items appear on Packing Exception page

=head1 DESCRIPTION

Test that cancelled items appear on Packing Exception page.

#TAGS fulfilment packingexception prl iws http orderview

=head1 METHODS

=cut

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw(
    :authorisation_level
    :packing_exception_action
    :shipment_item_status
);
use XTracker::Database qw( :common );
use Test::More::Prefix qw( test_prefix );
use XT::Domain::PRLs;
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::RunCondition export => [qw($iws_rollout_phase $prl_rollout_phase)];

sub startup : Test(startup) {
    my ( $self ) = @_;

    test_prefix('Startup');

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Feature::AppMessages',
            'Test::XT::Flow::Fulfilment',
            'Test::XT::Flow::CustomerCare'

        ],
    );

    $self->{framework}->clear_sticky_pages;
}

sub setup : Test(setup => 4) {
    my ( $self ) = @_;

    test_prefix('Setup');

    $self->{framework}->clear_sticky_pages;
    $self->{framework}->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
            'Customer Care/Customer Search',
            'Customer Care/Order Search',
            'Fulfilment/Packing',
            'Fulfilment/Packing Exception',
            'Fulfilment/Commissioner',
        ]},
        dept => 'Customer Care'
    });

    $self->{framework}->mech->force_datalite(1);

    # Get four products
    my ( $channel, $pids ) = Test::XTracker::Data->grab_products({ how_many => 2 });
    my %products = map {; "P$_" => shift( @$pids ) } 1..(scalar @$pids);

    # Get two totes
    my @totes = Test::XT::Data::Container->get_unique_ids( { how_many => 2 } );
    my %totes = map {; "T$_" => shift( @totes ) } 1..(scalar @totes);

    # Create an order with those four products and put them in the first tote
    $self->{order_hash}
        = $self->{framework}->flow_db__fulfilment__create_order_picked(
            channel  => $channel,
            products => [ @products{ 'P1' .. 'P2' } ],
            tote_id  => $totes{'T1'}
        );

    # Save products and totes for tests
    $self->{products} = \%products;
    $self->{totes} = \%totes;

    # Make sure we have a packing station
    $self->{framework}->mech__fulfilment__set_packing_station( $channel->id );
}

=head2 test_cancelled_items_to_pe

=cut

sub test_cancelled_items_to_pe : Tests {
    my ( $self, ) = @_;

    test_prefix( (caller(0))[3] =~ m{(\w+)$} );

    my $flow = $self->{framework};

    # We should have two items - we'll cancel one, and then say the other
    # one is missing
    my ( $item_to_cancel, $item_to_lose )
        = $self->{order_hash}{order_object}->get_standard_class_shipment
                                           ->shipment_items
                                           ->all;
    my $sku_to_cancel = $item_to_cancel->variant->sku;
    my $sku_to_lose   = $item_to_lose->variant->sku;
    # Cancel one shipment item
    $flow->flow_mech__customercare__orderview( $self->{order_hash}{order_object}->id )
         ->flow_mech__customercare__cancel_shipment_item
         ->flow_mech__customercare__cancel_item_submit( $sku_to_cancel )
         ->flow_mech__customercare__cancel_item_email_submit;

    $flow->flow_mech__fulfilment__packing
         ->flow_mech__fulfilment__packing_submit( $self->{totes}{T1} );

    note "now to pack container ".$self->{totes}{T1}." with cancelled sku $sku_to_cancel and other sku $sku_to_lose";
    # Mark other item as missing (which forces everything to go straight
    # to packing exception) and place remaining items in PE Tote
    $flow->flow_mech__fulfilment__packing_checkshipment_submit(
        missing => [ $sku_to_lose ],
    );

    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    my $pe_tote_id = $self->{totes}{T2};
    $flow->assert_location(qr{/Fulfilment/Packing/EmptyTote\b});
    $flow->flow_mech__fulfilment__packing_emptytote_submit('no');
    $flow->assert_location(qr{/Fulfilment/Packing/PlaceInPEOrphan\b});
    $flow->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_item( $sku_to_cancel )
         ->flow_mech__fulfilment__packing_placeinpeorphan_tote_scan_tote( $pe_tote_id )
         ->flow_mech__fulfilment__packing_placeinpeorphan_tote_mark_complete;


    if ($prl_rollout_phase) {
        my $number_of_prls = XT::Domain::PRLs::get_number_of_prls;
        my $pe_route_destination = XT::Domain::PRLs::get_conveyor_destination_id(
            "PackingOperations/packing_exception",
        );
        $xt_to_prls->expect_messages({
            messages => [
                ({
                    '@type' => 'container_empty',
                }) x $number_of_prls,
                {
                    '@type'     => 'route_request',
                    'details'   => { destination => $pe_route_destination },
                },
            ],
        });
    }
}

=head2 test_missing_cancelled_item

=cut

sub test_missing_cancelled_item : Tests {
    my ( $self, ) = @_;

    test_prefix( (caller(0))[3] =~ m{(\w+)$} );

    my $flow = $self->{framework};

    $flow->flow_mech__fulfilment__packing
         ->flow_mech__fulfilment__packing_submit( $self->{totes}{T1} );

    # We should have two items - we'll say one of them is missing and then
    # cancel it while it's on its way to packing exception
    my ( $item_to_cancel, $ok_item )
        = $self->{order_hash}{order_object}->get_standard_class_shipment
                                           ->shipment_items
                                           ->all;
    my $sku_to_cancel = $item_to_cancel->variant->sku;
    # Mark item as missing and place remaining items in PE Tote
    $flow->catch_error(
        qr{send to the packing exception},
        'Send to packing exception message issued',
        flow_mech__fulfilment__packing_checkshipment_submit => (
            missing => [ $sku_to_cancel ],
        ),
    );

    shipment_item_status_log_tests(
        $item_to_cancel, $SHIPMENT_ITEM_STATUS__PACKING_EXCEPTION,
        $PACKING_EXCEPTION_ACTION__MISSING
    );

    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    my $pe_tote_id = $self->{totes}{T2};
    $flow->assert_location(qr{/Fulfilment/Packing/PlaceInPEtote\b});
    $flow->flow_mech__fulfilment__packing_placeinpetote_scan_item( $ok_item->variant->sku )
         ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $pe_tote_id )
         ->flow_mech__fulfilment__packing_placeinpetote_mark_complete;

    my $number_of_prls = XT::Domain::PRLs::get_number_of_prls;
    $xt_to_prls->expect_messages({
        messages => [
            ({
                '@type' => 'container_empty',
            }) x $number_of_prls,
            # We're only interested in the container_empty messages, but
            # there's no way to ignore this one.
            {
                '@type' => 'route_request',
            },
        ],
    }) if $prl_rollout_phase;

    # Cancel shipment item
    $flow->flow_mech__customercare__orderview( $self->{order_hash}{order_object}->id )
         ->flow_mech__customercare__cancel_shipment_item
         ->flow_mech__customercare__cancel_item_submit( $sku_to_cancel )
         ->flow_mech__customercare__cancel_item_email_submit;

    # Confirm missing shipment and check message
    $flow->flow_mech__fulfilment__packingexception
         ->flow_mech__fulfilment__packingexception_submit( $pe_tote_id )
         ->flow_mech__fulfilment__packingexception_shipment_item_mark_missing(
            $sku_to_cancel,
        );
    $flow->mech->has_feedback_success_ok(
        qr{Cancelled item $sku_to_cancel has been marked as missing} );

    shipment_item_status_log_tests(
        $item_to_cancel, $SHIPMENT_ITEM_STATUS__CANCELLED,
        $PACKING_EXCEPTION_ACTION__MISSING
    );
}

sub shipment_item_status_log_tests {
    my ($shipment_item, $shipment_item_status_id, $packing_exception_action_id) = @_;
    isa_ok(
        my $si_log = $shipment_item->search_related('shipment_item_status_logs',
            undef, { order_by => { -desc => 'date', }, rows => 1 }
        )->single, 'XTracker::Schema::Result::Public::ShipmentItemStatusLog'
    );
    for (
        [ shipment_item_status_id     => $shipment_item_status_id     ],
        [ packing_exception_action_id => $packing_exception_action_id ],
    ) {
        my ( $col, $expected ) = @$_;
        is( $si_log->$col, $expected, "$col value set correctly" );
    }
}

=head2 test_cancelled_items_sticky

=cut

sub test_cancelled_items_sticky : Tests {
    my ( $self ) = @_;

    $self->_test_cancelled_items( { sticky => 1 } );
}

=head2 test_cancelled_items_nonsticky

=cut

sub test_cancelled_items_nonsticky : Tests {
    my ( $self ) = @_;

    $self->_test_cancelled_items( { sticky => 0 } );
}

sub _test_cancelled_items {
    my ( $self, $args) = @_;

    my $sticky = $args->{sticky} // 0;
    my $framework = $self->{framework};

    test_prefix(($sticky ? '' : 'Non-').'Sticky - Test Cancelled Items');
    $framework
        ->force_sticky_pages( $sticky );

    # Pack the shipment
    $framework
        ->flow_mech__fulfilment__packing
        ->flow_mech__fulfilment__packing_submit( $self->{totes}{T1} );

    # Fail products P1 and P2
    $framework
        ->catch_error(
            qr/send to the packing exception/,
            'Send to packing exception message issued',
            flow_mech__fulfilment__packing_checkshipment_submit => (
                fail => {
                    $self->_sku('P1') => 'Has clearly been on fire at some point',
                },
            ),
        );

    # We should be in PIPE
    $framework
        ->assert_location(qr{/Fulfilment/Packing/PlaceInPEtote\b})
        ->assert_sticky;

    {
    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    # Move each item to tote T2
    for ( 'P1' .. 'P2' ) {
        $framework
            ->flow_mech__fulfilment__packing_placeinpetote_scan_item( $self->_sku($_) )
            ->assert_sticky
            ->flow_mech__fulfilment__packing_placeinpetote_scan_tote( $self->{totes}{T2} )
            ->assert_sticky;
    }
    my $number_of_prls = XT::Domain::PRLs::get_number_of_prls;
    $xt_to_prls->expect_messages({
        messages => [
            ({
                '@type' => 'container_empty',
            }) x $number_of_prls,
        ],
    }) if $prl_rollout_phase;
    }

    # Complete PIPE process and return to packing screen
    $framework
        ->flow_mech__fulfilment__packing_placeinpetote_mark_complete
        ->flow_mech__fulfilment__packing;
}

sub _sku {
    my ( $self, $num ) = @_;
    return $self->{products}{$num}{sku};
}

1;
