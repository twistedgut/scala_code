package Test::XT::Data::Packing::Summary;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with "Test::Role::WithSchema";
}
use Test::XTracker::RunCondition prl_phase => 'prl';


use Test::More::Prefix qw/ test_prefix /;

use XT::Data::Packing::Summary;
use Test::XT::Fixture::Fulfilment::Shipment;
use Test::XTracker::Data::PackRouteTests;
use XTracker::Constants::FromDB qw(
    :physical_place
);

BEGIN {

has fixture => (
    is      => "ro",
    default => sub { Test::XT::Fixture::Fulfilment::Shipment->new() },
);

}

sub startup : Tests(startup) {
    my $self = shift;
    $self->SUPER::startup();

    my $pack_route_test = Test::XTracker::Data::PackRouteTests->new();
    $pack_route_test->reapply_config(
        $pack_route_test->like_live_packlane_configuration(),
    );
}

sub basic : Tests() {
    my $self = shift;

    dies_ok(
        sub { XT::Data::Packing::Summary->new() },
        "new with missing params dies ok",
    );

}

sub pack_lane__no_containers : Tests() {
    my $self = shift;
    my $fixture = $self->fixture;
    $fixture->discard_changes();

    $self->schema->txn_dont(sub {
        eq_or_diff(
            [ $fixture->shipment_row->containers ],
            [ ],
            "Setup sanity check: no Containers",
        );

        my $packing_summary = XT::Data::Packing::Summary->new({
            shipment_row => $fixture->shipment_row,
        });
        is($packing_summary->pack_lane, "", "No Containers, no pack_lane")
    });
}

sub pack_lane__containers__no_pack_lane : Tests() {
    my $self = shift;
    my $fixture = $self->fixture;
    $fixture->discard_changes();

    $self->schema->txn_dont(sub {
        $fixture->with_picked_shipment();
        $fixture->discard_changes();

        my $packing_summary = XT::Data::Packing::Summary->new({
            shipment_row => $fixture->shipment_row,
        });
        is(
            $packing_summary->pack_lane,
            "",
            "Picked Container, not yet staged => no pack_lane",
        );
    });
}

sub pack_lane__containers__pack_lane_assigned : Tests() {
    my $self = shift;
    my $fixture = $self->fixture;

    $fixture->discard_changes();
    $self->schema->txn_dont(sub {
        $fixture->with_picked_shipment();
        my $picked_container_row = $fixture->picked_container_row;
        $picked_container_row->choose_packlane();
        my $expected_pack_lane = $picked_container_row->pack_lane->human_readable_name();
        $fixture->discard_changes();

        my $packing_summary = XT::Data::Packing::Summary->new({
            shipment_row => $fixture->shipment_row,
        });
        is(
            $packing_summary->pack_lane,
            $expected_pack_lane,
            "Picked Container, assigned a packlane => pack_lane ($expected_pack_lane)",
        );
    });
}

sub as_string : Tests() {
    my $self = shift;

    my $fixture = $self->fixture;

    $fixture->discard_changes();
    $self->schema->txn_dont(sub {
        $fixture
            ->with_picked_shipment()
            ->with_shipment_items_moved_into_additional_containers();
        my $picked_container_row = $fixture->picked_container_row;
        $picked_container_row->choose_packlane();
        my $expected_pack_lane = $picked_container_row->pack_lane->human_name();
        $fixture->discard_changes();

        my $packing_summary = XT::Data::Packing::Summary->new({
            shipment_row => $fixture->shipment_row,
        });
        # Note: if this starts to fail intermittently, loosen up the
        # test of ordering of these
        like(
            $packing_summary->as_string,
            qr/^Multi tote pack lane \d+: \w+ \(at induction\), \w+ \(at induction\), \w+ \(en route\)/,
            "as_string ok",
        );
    });
}


