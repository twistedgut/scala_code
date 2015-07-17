package Test::XTracker::Schema::Result::Public::Container;

=head1 NAME

Test::XTracker::Schema::Result::Public::Container

=head1 DESCRIPTION

Unit tests for Container.

#TAGS shouldbeunit fulfilment phase0 prl checkruncondition

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN {
    extends "NAP::Test::Class";
    with "Test::Role::WithSchema";
};
use Test::XTracker::RunCondition prl_phase => 0;

use Test::XT::Data::Container;

=head2 packing_summary

Verify the Container's packing summary is correct for:

    * Regular container, no extra description
    * Container in Commissioner => Commissioner
    * Container in commissioner and in the Cage => in Commissioner, in Cage

=cut

sub packing_summary : Tests() {
    my $self = shift;

    my $container_row = Test::XT::Data::Container->create_new_container_row();
    my $container_id = $container_row->id;

    is(
        $container_row->packing_summary,
        "$container_id",
        "Regular container, no extra description",
    );


    # This isn't the actual case in DC1 / DC3 because they don't use
    # the Commissioner, but it's a theoretically valid scenario to
    # have an assigned "place"
    note "Put in Commissioner";
    $container_row->update({ place => "Commissioner" });
    is(
        $container_row->packing_summary,
        "$container_id (Commissioner)",
        "Container in Commissioner => Commissioner",
    );

    # This isn't the actual case in DC1 / DC3 because while they have
    # a Cage, Containers are never actually flagged as being
    # there. But it's a theoretically valid scenario to have an
    # assigned "plysical_place"
    my $cage_row = $self->search_one( PhysicalPlace => { name => "Cage" } );
    $container_row->update({ physical_place_id => $cage_row->id });

    is(
        $container_row->packing_summary,
        "$container_id (Cage, Commissioner)",
        "Container in commissioner and in the Cage => in Commissioner, in Cage",
    );

}

