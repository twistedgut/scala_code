package Test::NAP::Commissioner::InductToPacking;

=head1 NAME

Test::NAP::Commissioner::InductToPacking - Test inducting totes to Packing

=head1 DESCRIPTION

Test inducting totes to Packing.

    * Happy path
    * Container is absent from commissioner
    * Multiple totes happy path
    * Bad container/shipment
    * Not ready for packing

#TAGS fulfilment packing induction packingexception http

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
BEGIN { extends "NAP::Test::Class" }
use Test::XTracker::RunCondition (
    prl_phase => "prl",
);

use DBIx::Class::RowRestore;
use Guard;

use Test::More::Prefix qw( test_prefix );

use XTracker::Constants::FromDB qw(
    :shipment_status
);
use Test::XT::Fixture::PackingException::Shipment;
use Test::XTracker::Data::PackRouteTests;


BEGIN {

has fixture => (
    is => "ro",
    default => sub {
        Test::XT::Fixture::PackingException::Shipment
            ->new()
            ->with_logged_in_user()
            ->with_picked_shipment()
            ->with_picked_container_in_commissioner;
    }
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

=head2 induct_to_packing__success

=cut

sub induct_to_packing__success : Tests {
    my ( $self, ) = @_;

    my $fixture = $self->fixture;
    my $container_id = $fixture->picked_container_row->id;
    my $flow = $fixture->flow;


    test_prefix("Scan container");
    $fixture->with_picked_container_in_commissioner();
    $flow->flow_mech__fulfilment__commissioner();

    $flow->flow_mech__fulfilment__commissioner__submit_induct_to_packing(
        $container_id,
    );
    like(
        $flow->mech->uri,
        qr|/Fulfilment/Induction\?container_id=$container_id&is_container_in_cage=0|,
        "Redirect url contains the Induction page and the container_id ($container_id)",
    );



    test_prefix("Scan container which is in the Cage");
    $fixture->with_picked_container_in_commissioner();
    $flow->flow_mech__fulfilment__commissioner();
    $flow->flow_mech__fulfilment__commissioner__check_is_in_cage(); # Tick
    $flow->flow_mech__fulfilment__commissioner__submit_induct_to_packing(
        $container_id,
    );
    like(
        $flow->mech->uri,
        qr|/Fulfilment/Commissioner|,
        "Redirect URL redirected to the Induction, which had only one answer"
        . " and immediately inducted the Container, and then redirected back"
        . " to the Commissioner",
    );
    like(
        $flow->mech->app_info_message(),
        qr/^Please take tote \w+ to/, # some pack lane
        "Correct user instruction to take the Container to a Pack Lane",
    );



    test_prefix("Scan shipment");
    $fixture->with_picked_container_in_commissioner();
    $flow->flow_mech__fulfilment__commissioner();

    $flow->flow_mech__fulfilment__commissioner__submit_induct_to_packing(
        $fixture->shipment_row->id,
    );
    like(
        $flow->mech->uri,
        qr|/Fulfilment/Induction\?container_id=$container_id&is_container_in_cage=0|,
        "Redirect url contains the Induction page and the container_id ($container_id)",
    );


    note "In Induction, answer the question 'Can the tote be conveyed?'";
    $flow->flow_mech__fulfilment__induction_answer_submit("yes");
    $fixture->discard_changes();

    note "Back at the Commissioner";
    like(
        $flow->mech->uri,
        qr|/Fulfilment/Commissioner$|,
        "After induction, redirects back to Commissioner page",
    );

    like(
        $flow->mech->app_info_message(),
        qr/^Please place tote \w+ onto the conveyor/,
        "Correct user instruction to put it on conveyor",
    );

    $self->test_container_is_absent_from_commissioner(
        $flow->mech,
        $container_id,
    );
    is(
        $fixture->picked_container_row->place,
        undef,
        "Container->place cleared (no longer in Commissioner)",
    );


    test_prefix("");
}

sub test_container_is_absent_from_commissioner {
    my ($self, $mech, $container_id) = @_;

    my @page_sections = (
        "Ready for Packing",
        "Shipment Cancelled",
        "Shipment On Hold",
        "No Action",
    );
    for my $section (@page_sections) {
        my $page_container_row = $self->_array_of_hashes_by_key(
            $mech->as_data->{ $section },
            "Container",
        );
        ok(
            ! $page_container_row->{ $container_id },
            "($container_id) is absent from $section on the Commissioner page",
        );
    }
}

# Transform an $array ref of hash refs to a hash ref (keys: the value of
# $key in each hash ref).
#
# transform: _array_of_hashes_by_key($array, "a")
#
# before: [
#     { a => 3, b => 5 },
#     { a => 2, b => 6 },
# ]
#
# after: {
#     3 => { a => 3, b => 5 },
#     2 => { a => 2, b => 6 },
# }
#
sub _array_of_hashes_by_key {
    my ($self, $array, $key) = @_;
    $array //= [];

    my $hash = { map { $_->{ $key } => $_ } @$array };
    return $hash;
}

sub _test_error_message {
    my ($self, $args) = @_;
    my $flow = $self->fixture->flow;

    $flow->flow_mech__fulfilment__commissioner();
    $flow->catch_error(
        $args->{error_message},
        $args->{description},
        flow_mech__fulfilment__commissioner__submit_induct_to_packing
            => ($args->{container_id}),
    );
    like(
        $flow->mech->uri,
        qr|/Fulfilment/Commissioner|,
        "Error message is displayed on redirect back to Commissioner page",
    );
}

=head2 induct_to_packing__multiple_totes__success

=cut

sub induct_to_packing__multiple_totes__success : Tests {
    my ( $self, ) = @_;
    # Make sure multiple totes are identified properly even when they
    # come from Packing Exception / the Commissioner

    my $fixture = Test::XT::Fixture::PackingException::Shipment
        ->new({ pid_count => 4 })
        ->with_logged_in_user()
        ->with_picked_shipment()
        ->with_shipment_items_moved_into_additional_containers
        ->with_picked_container_in_commissioner;

    my $container_id = $fixture->picked_container_row->id;
    my $flow = $fixture->flow;


    test_prefix("Scan container");
    $flow->flow_mech__fulfilment__commissioner();

    $flow->flow_mech__fulfilment__commissioner__submit_induct_to_packing(
        $container_id,
    );
    like(
        $flow->mech->uri,
        qr|/Fulfilment/Induction\?container_id=$container_id&is_container_in_cage=0|,
        "Redirect url contains the Induction page and the container_id ($container_id)",
    );

    like(
        $flow->mech->app_info_message(),
        qr/must be inducted together with $container_id/,
        "Correct user instruction for multiple totes",
    );
}

=head2 induct_to_packing__bad_container_shipping_id

=cut

sub induct_to_packing__bad_container_shipping_id : Tests {
    my ( $self, ) = @_;

    my $container_id = "abcMISSINGdef";
    my $error_message = "There is no Container/Shipment '$container_id'";
    $self->_test_error_message({
        description   => "Display user error message when Invalid Container/Shipment",
        container_id  => $container_id,
        error_message => $error_message,
    });
}

=head2 induct_to_packing__not_ready_for_packing

=cut

sub induct_to_packing__not_ready_for_packing : Tests {
    my ( $self, ) = @_;

    note "* Setup";
    my $fixture = $self->fixture;
    my $container_id = $fixture->picked_container_row->id;
    my $flow = $fixture->flow;

    note "Temporarily set the ShipmentItem to be in Packing Exception";
    my $row_restore = DBIx::Class::RowRestore->new();
    my $row_guard = guard { $row_restore->restore_rows };
    $row_restore->add_to_update(
        $fixture->shipment_row,
        { shipment_status_id => $SHIPMENT_STATUS__HOLD },
    );
    $fixture->discard_changes();


    note "* Test";
    my $error_message = "The Shipments in Container '$container_id' aren't ready for Packing";
    $self->_test_error_message({
        description   => "Display error when Shipment not ready for Packing is scanned",
        container_id  => $container_id,
        error_message => $error_message,
    });

}

