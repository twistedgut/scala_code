package Test::XT::Data::PRL::Conveyor::Route::ToPacking;
use NAP::policy "tt", "class","test";
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};
use Test::XTracker::RunCondition(
    # Needs <PRL/Conveyor> config, currently only configured for DC2.
    # When configuring for other DCs, deal with the hardcoded route
    # destination values.
    dc => "DC2",
);

use XT::Data::PRL::Conveyor::Route::ToPacking;
use Test::XT::Data::Container;
use Test::XTracker::Artifacts::RAVNI;

use Test::XTracker::Data::PackRouteTests;
use Test::XT::Fixture::Route::Container;

sub startup :Tests(startup) {
    my $self = shift;

    $self->SUPER::startup;
    my $plt = Test::XTracker::Data::PackRouteTests->new;

    $plt->reapply_config($plt->like_live_packlane_configuration());

}

sub constructor : Tests() {
    my $self = shift;

    throws_ok(
        sub { XT::Data::PRL::Conveyor::Route::ToPacking->new({ schema => $self->schema }) },
        qr/Please specify either of container_id, container_row, container_ids, container_rows/,
        "new without any containers dies ok",
    );

    throws_ok(
        sub { XT::Data::PRL::Conveyor::Route::ToPacking->new({
            schema       => $self->schema,
            container_id => "Missing container id",
        }) },
        qr/\QCould not find Container (Missing container id)/,
        "new with missing container_id dies properly",
    );
    throws_ok(
        sub { XT::Data::PRL::Conveyor::Route::ToPacking->new({
            schema        => $self->schema,
            container_ids => [ "Missing container ids" ],
        }) },
        qr/\QCould not find Container (Missing container ids)/,
        "new with missing container_ids dies properly",
    );

    my $fixture = Test::XT::Fixture::Route::Container->new();
    my $route;
    lives_ok(
        sub {
            $route = XT::Data::PRL::Conveyor::Route::ToPacking->new({
                schema       => $self->schema,
                container_id => $fixture->container_id,
            });
        },
        "new with existing container_id alright",
    );
    is(
        $route->container_row->id,
        $fixture->container_id,
        "container_row is the specified container",
    );
    is(scalar @{$route->container_rows}, 1, "Got one container");
    is(
        $route->container_rows->[0]->id,
        $fixture->container_id,
        "    and the first container_rows is the specified container",
    );
}

sub get_destination__normal : Tests() {
    no warnings 'redefine';
    my $self = shift;

    my $fixture = Test::XT::Fixture::Route::Container->new()
        ->with_shipment_in_container();

    my $route = XT::Data::PRL::Conveyor::Route::ToPacking->new({
        schema       => $self->schema,
        container_id => $fixture->container_id,
    });

    # override search results so we can get a predictable result.
    my $any_packlane = $self->schema->resultset('Public::PackLane')->search()->first;

    local *XTracker::Schema::ResultSet::Public::PackLane::select_pack_lane = sub {
        return $any_packlane;
    };

    is(
        $route->get_route_destination,
        "PackLanes/". $any_packlane->human_name(),
        "get_route_destination for container that doesn't contain any shipments on hold returns whatever the Pack Lane Manager returns",
    );
}

