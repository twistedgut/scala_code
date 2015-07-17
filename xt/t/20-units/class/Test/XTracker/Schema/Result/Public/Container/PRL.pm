package Test::XTracker::Schema::Result::Public::Container::PRL;

=head1 NAME

Test::XTracker::Schema::Result::Public::Container::PRL

=head1 DESCRIPTION

Tests some things around packing and inducting containers.

#TAGS fulfilment packing prl

=head1 SEE ALSO

L<Test::XTracker::Schema::ResultSet::Public::Container>

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with "Test::Role::WithSchema";
};

use Test::XTracker::RunCondition prl_phase => 'prl';

use XTracker::Constants::FromDB qw(
    :shipment_status
);

use Test::XT::Data::Container;
use Test::XT::Fixture::PackingException::Shipment;
use XTracker::Schema::Result::Public::Container;
use Test::XTracker::MessageQueue;

use Test::XT::Fixture::Fulfilment::Shipment;

=head2 packing_summary

=cut

sub packing_summary : Tests() {
    my $self = shift;

    my $container_row = Test::XT::Data::Container->create_new_container_row();
    my $container_id = $container_row->id;

    is(
        $container_row->packing_summary,
        "$container_id (at induction)",
        "Not inducted, no place => at induction",
    );


    note "Put in Commissioner";
    $container_row->update({ place => "Commissioner" });
    is(
        $container_row->packing_summary,
        "$container_id (Commissioner)",
        "Not inducted, in Commissioner => Commissioner",
    );
}

=head2 packing_summary__not_inducted

=cut

sub packing_summary__not_inducted : Tests() {
    my $self = shift;

    my $container_row = Test::XT::Data::Container->create_new_container_row();
    my $container_id = $container_row->id;

    is(
        $container_row->packing_summary,
        "$container_id (at induction)",
        "Not inducted, no place => at induction",
    );
}

=head2 packing_summary__not_inducted__still_in_commissioner

=cut

sub packing_summary__not_inducted__still_in_commissioner : Tests() {
    my $self = shift;

    my $container_row = Test::XT::Data::Container->create_new_container_row();
    $container_row->update({ place => "Commissioner" });
    my $container_id = $container_row->id;

    is(
        $container_row->packing_summary,
        "$container_id (Commissioner)",
        "Not inducted, still in Commissioner",
    );
}

sub _get_pack_lane_id {
    my $self = shift;

    $self->{__pack_lane_id} ||= time;
    return $self->{__pack_lane_id}++;
}

=head2 packing_summary__inducted_from_commissioner__in_cage

=cut

sub packing_summary__inducted_from_commissioner__in_cage : Tests() {
    my $self = shift;

    my $pack_lane_row = $self->schema->resultset("Public::PackLane")->create({
        pack_lane_id  => $self->_get_pack_lane_id,
        human_name    => "testing" . time(),
        internal_name => "TESTING" . time(),
        capacity      => 7,
        active        => 1,
    });
    my $container_row = Test::XT::Data::Container->create_new_container_row();
    my $container_id = $container_row->id;
    my $cage_row = $self->search_one( PhysicalPlace => { name => "Cage" } );
    $container_row->update({
        pack_lane_id      => $pack_lane_row->id,
        place             => "Commissioner",
        physical_place_id => $cage_row->id,
    });

    note "Not arrived";
    is(
        $container_row->packing_summary,
        "$container_id (Cage, Commissioner)",
        "Inducted, in Commissioner, in Cage => Commissioner, Cage",
    );

    note "Arrived";
    $container_row->update({
        has_arrived => 1,
    });

    is(
        $container_row->packing_summary,
        "$container_id (Cage, Commissioner)",
        "Inducted + arrived => in Commissioner, in Cage",
    );
}

=head2 packing_summary__inducted

=cut

sub packing_summary__inducted : Tests() {
    my $self = shift;

    my $pack_lane_row = $self->schema->resultset("Public::PackLane")->create({
        pack_lane_id  => $self->_get_pack_lane_id,
        human_name    => "testing1" . time(),
        internal_name => "TESTING1" . time(),
        capacity      => 7,
        active        => 1,
    });
    my $container_row = Test::XT::Data::Container->create_new_container_row;
    my $container_id = $container_row->id;
    $container_row->update({
        pack_lane_id      => $pack_lane_row->id,
        place             => "Commissioner",
    });

    note "Not arrived";
    is(
        $container_row->packing_summary,
        "$container_id (en route, Commissioner)",
        "Inducted, in Commissioner, but still not arrived - en route",
    );

    note "Arrived";
    $container_row->update({
        has_arrived => 1,
    });

    is(
        $container_row->packing_summary,
        "$container_id (arrived)",
        "Inducted + arrived ",
    );
}

=head2 are_all_shipments_on_hold

=cut

sub are_all_shipments_on_hold :Tests() {
    my ($self) = @_;

    my $container_row = Test::XT::Data::Container->create_new_container_row();
    ok(
        ! $container_row->are_all_shipments_on_hold,
        "Empty Container - are_all_shipments_on_hold is false",
    );

    # Vanilla data object to instatiate fixture without a flow mech dependency
    my $data = Test::XT::Data->new_with_traits(
        traits  => [ 'Test::XT::Data::Order' ]
    );

    my $fixture = Test::XT::Fixture::PackingException::Shipment
        ->new({flow => $data})
        ->with_picked_shipment();
    my $picked_container_row = $fixture->picked_container_row;
    ok(
        ! $picked_container_row->are_all_shipments_on_hold,
        "Container with Picked Shipment - are_all_shipments_on_hold is false",
    );


    $fixture->shipment_row->update({
        shipment_status_id => $SHIPMENT_STATUS__HOLD,
    });
    $fixture->discard_changes();
    ok(
        $picked_container_row->are_all_shipments_on_hold,
        "Container with Picked Shipment on Hold - are_all_shipments_on_hold is true",
    );
}

=head2 send_container_empty

=cut

sub send_container_empty :Tests() {
    my $amq = Test::XTracker::MessageQueue->new;
    $amq->clear_destination('queue/test.1');

    my ($container) =
        Test::XT::Data::Container->create_new_container_rows;
    lives_ok {
        $container->send_container_empty_to_prls({
            amq => $amq,
            destinations => 'queue/test.1',
        });
    } 'Call send_container_empty_to_prls()';

    note 'Check the number of sent messages';
    $amq->assert_messages({
            destination  => 'queue/test.1',
            assert_count => 1,
            assert_head  => superhashof({ '@type' => 'container_ready' }),
            assert_body  => superhashof({ container_id => $container->id . '' }),
        },
        'One message was sent and contents are correct',
    );
}

=head2 is_ready_for_induction

=cut

sub is_ready_for_induction :Tests() {
    my $self = shift;
    my $fixture = Test::XT::Fixture::Fulfilment::Shipment->new();

    ok(
        ! $fixture->additional_container_rows->[0]->is_ready_for_induction(),
        "Empty Container is not ready for packing",
    );

    $fixture->with_staged_shipment();
    ok(
        $fixture->picked_container_row->is_ready_for_induction,
        "Staged shipment is ready for packing",
    );

    $fixture->with_picked_shipment();
    ok(
        ! $fixture->picked_container_row->is_ready_for_induction,
        "Fully Packed shipment is not ready for packing",
    );
}

