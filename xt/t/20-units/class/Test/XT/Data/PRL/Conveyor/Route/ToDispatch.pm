package Test::XT::Data::PRL::Conveyor::Route::ToDispatch;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};
use Test::XTracker::RunCondition(
    # Needs <PRL/Conveyor> config, currently only configured for DC2.
    # When configuring for other DCs, deal with the hardcoded route
    # destination values.
    dc     => "DC2",
    export => [ '$distribution_centre' ],
);

use XT::Data::PRL::Conveyor::Route::ToDispatch;
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

use Test::XT::Fixture::Route::ShipmentInBox;

sub is_conveyed_in_tote : Tests() {
    my $self = shift;

    my $fixture = Test::XT::Fixture::Route::ShipmentInBox->new();
    my $route = XT::Data::PRL::Conveyor::Route::ToDispatch->new({
        schema           => $self->schema,
        shipment_row     => $fixture->shipment_row,
        shipment_box_row => $fixture->shipment_box_row,
    });
    ok(
        ! $route->is_conveyed_in_tote,
        "is_conveyed_in_tote without a tote is false",
    );

    $fixture->with_box_in_container();
    ok(
        $route->is_conveyed_in_tote,
        "is_conveyed_in_tote with the box in a Tote is true",
    );
}

sub is_premier : Tests() {
    my $self = shift;

    my $fixture = Test::XT::Fixture::Route::ShipmentInBox->new();
    my $route = XT::Data::PRL::Conveyor::Route::ToDispatch->new({
        schema           => $self->schema,
        shipment_row     => $fixture->shipment_row,
        shipment_box_row => $fixture->shipment_box_row,
    });
    ok(
        ! $route->is_premier,
        "is_premier with Domestic ShippingCharge is false",
    );

    $fixture->with_shipment_is_premier();
    ok(
        $route->is_premier,
        "is_premier with Premier ShippingCharge is true",
    );
}

sub _get_route_and_fixture {
    my ($self, %args) = @_;

    my $fixture = Test::XT::Fixture::Route::ShipmentInBox->new();
    if($args{with_real_time_carrier_booking}) {
        $fixture->with_shipment_real_time_carrier_booking();
    }

    my $route = XT::Data::PRL::Conveyor::Route::ToDispatch->new({
        schema                 => $self->schema,
        shipment_row           => $fixture->shipment_row,
        shipment_box_row       => $fixture->shipment_box_row,
    });

    return ($route, $fixture);
}

sub get_destination__can_be_carton_sealed__domestic : Tests() {
    my $self = shift;
    my ($route, $fixture) = $self->_get_route_and_fixture(
        with_real_time_carrier_booking => 1,
    );
    is(
        $route->get_route_destination,
        "DispatchLanes/any_carton_sealer",
        "Domestic, can be carton sealed destination ok",
    );
}

sub get_destination__can_be_carton_sealed__premier : Tests() {
    my $self = shift;
    # This combo of carrier automation (implies UPS) and premier
    # (implies not UPS) isn't really going to happen.

    my ($route, $fixture) = $self->_get_route_and_fixture(
        with_real_time_carrier_booking => 1,
    );
    $fixture->with_shipment_is_premier();

    is(
        $route->get_route_destination,
        "DispatchLanes/any_carton_sealer",
        "Premier, can be carton sealed destination ok",
    );
}

sub get_destination__in_tote__is_automated__domestic : Tests() {
    my $self = shift;
    my ($route, $fixture) = $self->_get_route_and_fixture(
        with_real_time_carrier_booking => 1,
    );
    $fixture->with_box_in_container();

    is(
        $route->get_route_destination,
        "DispatchLanes/premier_dispatch",
        "Domestic, can not be carton sealed (in container), destination ok",
    );
}

sub get_destination__not_automated__domestic : Tests() {
    my $self = shift;
    my ($route, $fixture) = $self->_get_route_and_fixture(
        with_real_time_carrier_booking => 0,
    );

    is(
        $route->get_route_destination,
        "DispatchLanes/premier_dispatch",
        "Domestic, can not be carton sealed (not automated => requires paperwork), destination ok",
    );
}

sub get_destination__can_not_be_carton_sealed__premier : Tests() {
    my $self = shift;
    my ($route, $fixture) = $self->_get_route_and_fixture(
        # can not be carton sealed
        with_real_time_carrier_booking => 0,
    );
    $fixture->with_shipment_is_premier();

    is(
        $route->get_route_destination,
        undef, # To Premier Dispatch Lane, but no routing required
        "Premier, can be carton sealed destination ok",
    );
}

sub send__premier__no_route_message_sent : Tests() {
    my $self = shift;
    my ($route, $fixture) = $self->_get_route_and_fixture(
        # can not be carton sealed
        with_real_time_carrier_booking => 0,
    );
    $fixture->with_shipment_is_premier();

    is(
        $route->send(),
        undef, # To Premier Dispatch Lane, but no routing required
        "Premier, no route returned (implies nothing sent)",
    );
}

