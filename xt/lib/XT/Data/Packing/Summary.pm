package XT::Data::Packing::Summary;
use NAP::policy "tt", "class";
with qw(
    XTracker::Role::WithSchema
);

=head1 NAME

XT::Data::Packing::Summary - A summary of the Packing progress of a Shipment

=head1 DESCRIPTION

The Shipment has items to be picked and packed. This class provides a
summary of outstanding Allocations/Picks and a list of Containers and
their wherabouts.

=cut

use List::MoreUtils qw/ first_value /;


has shipment_row => (
    is       => "ro",
    required => 1,
);

has container_rows => (
    is      => "ro",
    lazy    => 1,
    default => sub { [
        sort { $a->id cmp $b->id }
        shift->shipment_row->containers(),
    ] },
);



=head1 METHODS


=head2 as_string() : $summary_string

Return string summarising the Packing status for the ->shipment_row:
Pack Lane destination, outstanding Allocations, and picked Containers
(and their whereabouts).

=cut

sub as_string {
    my $self = shift;
    my $pack_lane = $self->pack_lane // "";
    $pack_lane &&= "$pack_lane: ";

    my $details = join(qq{, },
        $self->allocation_summaries,
        $self->container_summaries,
    );

    return "$pack_lane$details";
}

=head2 pack_lane() : $pack_lane_string | ""

Return a human-readable pack lane string the Shipment is assigned, or
"" if there isn't one yet.

=cut

sub pack_lane {
    my $self = shift;
    my $container_row =
        first_value { $_->pack_lane_id }
        @{$self->container_rows}
            or return "";
    return $container_row->pack_lane->human_readable_name;
}

=head2 allocation_summaries() : @allocation_packing_summary

Return list of a packing_summary for each Allocation in the Shipment
that isn't yet picked into a Container (could very well be an empty
list).

=cut

sub allocation_summaries {
    my $self = shift;
    return
        grep { $_ }
        map  { $_->packing_summary }
        sort { $a->id <=> $b->id }
        $self->shipment_row->allocations();
}

=head2 container_summaries() : @container_packing_summary

Return list of a packing_summary for each Container in the Shipment.

=cut

sub container_summaries {
    my $self = shift;
    return
        map { $_->packing_summary }
        @{$self->container_rows};
}

