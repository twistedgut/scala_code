package Test::XTracker::Schema::ResultSet::Public::Prl;
use NAP::policy "tt", qw/test class/;
use FindBin::libs;
BEGIN {
    extends 'NAP::Test::Class';
    with qw/
        Test::Role::WithSchema
    /;
};
use Test::XTracker::RunCondition prl_phase => 'prl';

=head1 NAME

Test::XTracker::Schema::ResultSet::Public::Prl - Unit tests for
XTracker::Schema::ResultSet::Public::Prl

=cut

use XTracker::Constants::FromDB qw(
    :prl
);
use vars qw/ $PRL__FULL /;

use Test::XT::Fixture::Fulfilment::Shipment;



sub prl_rs        { shift->schema->resultset("Public::Prl") }
sub allocation_rs { shift->schema->resultset("Public::Allocation") }

sub staging_total_capacity {
    my $self = shift;
    $self->schema->resultset(
        "SystemConfig::Parameter",
    )->search({ name => "full_staging_total_capacity"})->first->value;
}

sub test__prl_allocation_filtered_count : Tests {
    my $self = shift;

    note "*** Setup";
    note "At least one allocation in picked";
    Test::XT::Fixture::Fulfilment::Shipment
        ->new()
        ->with_allocated_shipment()
        ->with_picked_shipment();

    note "Calculate expected output using a simpler method";
    my $expected_prl_count = {};
    for my $prl_row ($self->prl_rs->all) {
        my $count = $self->allocation_rs->filter_picking->search(
            { "prl.id" => $prl_row->id },
            { join     => "prl"},
        )->count;
        $count and $expected_prl_count->{ $prl_row->identifier_name } = $count;
    }


    my $prl_rs = $self->schema->resultset("Public::Prl");
    my $prl_allocation_in_picking_count = $prl_rs->prl_count_to_hashref(
        scalar $self->allocation_rs->filter_picking->prl_allocation_count_rs(),
    );

    cmp_deeply(
        $prl_allocation_in_picking_count,
        $expected_prl_count,
        "Manual calculation matches group_by in prl_allocation_filtered_count",
    );
}

sub test__prl_container_in_staging_count : Tests {
    my $self = shift;

    note "*** Setup";
    note "At least one allocation with container in staged";
    Test::XT::Fixture::Fulfilment::Shipment
        ->new()
        ->with_normal_sla()
        ->with_staged_shipment()
        ->with_shipment_items_moved_into_additional_containers(); # in total 3


    note "Calculate expected output using a simpler method";
    my $expected_prl_count = {};
    for my $prl_row ($self->prl_rs->all) {
        my $count
            = $self->allocation_rs->filter_staged->search(
                { "prl.id" => $prl_row->id },
                { join     => "prl"},
            )
            ->search_related("allocation_items")
            ->search_related("shipment_item")
            ->search_related("container", undef, { distinct => 1 })->count;
        $count and $expected_prl_count->{ $prl_row->identifier_name } = $count;
    }


    my $prl_rs = $self->schema->resultset("Public::Prl");
    my $prl_container_in_staged_count = $prl_rs->prl_count_to_hashref(
        scalar $self->allocation_rs->filter_staged->prl_container_count_rs(),
    );

    eq_or_diff(
        $prl_container_in_staged_count->{full},
        $expected_prl_count->{full},
        "Manual calculation for Full matches group_by in prl_container_filtered_count",
    );
}
