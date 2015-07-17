package Test::NAP::PackingException::CancelledOrderBeforePacking;

=head1 NAME

Test::NAP::PackingException::CancelledOrderBeforePacking - When cancelling an order before packing

=head1 DESCRIPTION

Cancel an order before packing, scan it at Packing Exception, verify user is
redirected to the View Order page.

#TAGS fulfilment putaway packingexception packing cancel

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
BEGIN { extends "NAP::Test::Class" }

use List::MoreUtils qw/ uniq /;

use Test::XTracker::Data;
use Test::XT::Flow;
use Test::More::Prefix qw( test_prefix );

use Test::XT::Fixture::PackingException::Shipment;
use Test::XT::Fulfilment::Putaway;
use XTracker::Constants::FromDB qw(
    :shipment_item_status
);
use XTracker::Config::Local qw( config_var );
use Test::XTracker::Artifacts::RAVNI;
use Test::XTracker::RunCondition export => qw($prl_rollout_phase);

=head2 packing_exception_redirects_to_view_order_page

=cut

sub packing_exception_redirects_to_view_order_page : Tests {
    my ( $self, ) = @_;

    test_prefix("Setup");
    my $fixture = Test::XT::Fixture::PackingException::Shipment
        ->new()
        ->with_logged_in_user()
        ->with_picked_shipment()
        ->with_cancelled_order();

    my $flow = $fixture->flow;
    my $to_packing_exception_container_row = $flow->task__packing__cancelled_order({
        container_row => $fixture->picked_container_row,
        shipment_row  => $fixture->shipment_row,
    });

    note "Scan container at PackingException";
    $flow
        ->flow_mech__fulfilment__packingexception
        ->flow_mech__fulfilment__packingexception_submit(
            $to_packing_exception_container_row->id,
        );

    my $to_packing_exception_container_id = $to_packing_exception_container_row->id;
    like(
        $flow->mech->uri,
        qr|/Fulfilment/PackingException/ViewContainer\?container_id=$to_packing_exception_container_id|,
        "   and we landed on the correct page",
    );


    # DC1: Container iws - cancelled, moved to iws, notified web site
    # DC2: Container     - cancel pending
    # DC2: Location      - cancel pending, in putaway location
    my $putaway_test = Test::XT::Fulfilment::Putaway->new_by_type({
        shipment_row => $fixture->shipment_row,
        flow         => $flow,
    });


    test_prefix("Run");
    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');
    $flow->flow_mech__fulfilment__packingexception__viewcontainer_putaway_ready();
    $putaway_test->test_user_message__marked_for_putaway(
        $to_packing_exception_container_row,
    );

    test_prefix("Test");
    $fixture->discard_changes();
    $to_packing_exception_container_row->discard_changes();

    note "Container is empty";
    my $number_of_prls = XT::Domain::PRLs::get_number_of_prls;
    $xt_to_prls->expect_messages({
        messages => [
            ({
                '@type' => 'container_empty',
            }) x $number_of_prls,
        ],
    }) if $prl_rollout_phase;
    ok(
        $to_packing_exception_container_row->is_empty,
        "The PE Container is now empty",
    );

    $putaway_test->test_shipment_items_status();
    $putaway_test->test_quantities_moved_to_location();
}

