use utf8;
package XTracker::Schema::Result::Public::PackLane;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pack_lane");
__PACKAGE__->add_columns(
  "pack_lane_id",
  { data_type => "integer", is_nullable => 0 },
  "human_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "internal_name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "capacity",
  { data_type => "integer", is_nullable => 0 },
  "active",
  { data_type => "boolean", is_nullable => 0 },
  "container_count",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "is_editable",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("pack_lane_id");
__PACKAGE__->add_unique_constraint("pack_lane_internal_name_key", ["internal_name"]);
__PACKAGE__->has_many(
  "containers",
  "XTracker::Schema::Result::Public::Container",
  { "foreign.pack_lane_id" => "self.pack_lane_id" },
  undef,
);
__PACKAGE__->has_many(
  "pack_lanes_has_attributes",
  "XTracker::Schema::Result::Public::PackLaneHasAttribute",
  { "foreign.pack_lane_id" => "self.pack_lane_id" },
  undef,
);
__PACKAGE__->many_to_many(
  "assigned_attributes",
  "pack_lanes_has_attributes",
  "attribute",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:S/deM6rY7Pric0DLcFM+nA

use List::Util 'max';

use XT::Domain::PRLs;

use XTracker::Constants::FromDB qw/
    :pack_lane_attribute
/;

=head1 NAME

XTracker::Schema::Result::Public::PackLane

=head1 DESRIPTION

DBIC Result class for pack_lane table

=head1 METHODS

=head2 add_attribute

Add an attribute to this packlane

param - $attribute_id : pack_lane_attribute_id value from pack_lane_attribute table to identify attribute to add

=cut
sub add_attribute {
    my ($self, $attribute_id) = @_;
    return $self->pack_lanes_has_attributes()->find_or_create({
        'pack_lane_attribute_id' => $attribute_id,
    });
}

=head2 remove_attribute

Remove an attribute to this packlane

param - $attribute_id : pack_lane_attribute_id value from pack_lane_attribute table to identify attribute to remove

=cut
sub remove_attribute {
    my ($self, $attribute_id) = @_;
    $self->pack_lanes_has_attributes()->search({
        'pack_lane_attribute_id' => $attribute_id,
    })->delete();
}

=head2 get_attribute_ids

Retrieve a hashref of attribute_ids that are assigned to this packlane,
    these map to db.pack_lane_attribute.pack_lane_attribute_id

return - $id_hash : The hashref of attribute ids, where key = attribute_id, value = 1

=cut

sub get_attribute_ids {
    my ($self) = @_;

    my @attributes = $self->assigned_attributes();
    my %id_hash = map { $_->pack_lane_attribute_id() => 1 } @attributes;
    return \%id_hash;

}


=head2 has_attribute ($attribute_id) : Boolean

Return a true value if the pack lane has the specified attribute.

=cut

sub has_attribute {
    my ($self, $attribute_id) = @_;

    return unless $attribute_id;

    return $self->pack_lanes_has_attributes->search({
        'pack_lane_attribute_id' => $attribute_id,
    })->count;
}


=head2 is_multitote : Boolean

Return a true value if this is a multi-tote pack lane.

=cut

sub is_multitote {
    my $self = shift;

    return $self->has_attribute($PACK_LANE_ATTRIBUTE__MULTITOTE);
}

=head2 get_available_capacity

Returns the calculated available capacity for the packlane.

=cut

sub get_available_capacity {
    my $self = shift;

    my $row = $self->_get_container_counts_row();

    # Available capacity is:
    #   Total packlane capacity.
    #   Minus the count of containers that are heading for the packlane but not yet arrived.
    #   Minus the count of containers that have arrived at the packlane
    my $worst_case_arrived = $self->get_containers_on_packlane_count($row);
    my $available_capacity = $self->capacity
                             - $self->get_containers_en_route_count($row)
                             - $worst_case_arrived;

    return $available_capacity;
}

=head2 get_containers_en_route_count

Return the numbers of containers that are curerntly en route to this
packing lane.

=cut

sub get_containers_en_route_count {
    my ($self, $row_with_container_counts) = @_;

    $row_with_container_counts //= $self->_get_container_counts_row();

    return $row_with_container_counts->get_column('known_unarrived_count');
}

=head2 get_containers_on_packlane_count

Returns the calculated available capacity for the packlane.

param - $row_with_container_counts : (Optional) as returned by _get_container_counts_row()
    if supplied, it avoids an extra call to the db to get the column data.

=cut

sub get_containers_on_packlane_count {
    my ($self, $row_with_container_counts) = @_;

    $row_with_container_counts //= $self->_get_container_counts_row();

    # We always assume the 'worst case' scenario, as we have two sources of data that tell us
    # how many containers are on a packlane and they may not match. This is either:
    #  - the arrived container count
    # or
    #  - the total that the packlane itself reports at the packlane
    return max(
        $row_with_container_counts->container_count,
        $row_with_container_counts->get_column('known_arrived_count')
    );
}

# Returns a version of the current packlane with two extra columns:
#  known_unarrived_count - Count of containers that report that they have NOT
#       arrived at this packlane
#  known_arrived_count - Count of containers that report that they HAVE
#       arrived at this packlane
#
# Both of these columns are accessable through ->get_column()
sub _get_container_counts_row {
    my ($self) = @_;

    return $self->result_source()->resultset()->search({
        pack_lane_id => $self->pack_lane_id(),
    }, {
        '+columns' => {
            'known_unarrived_count' => $self->search_related('containers', {
                    has_arrived => 0
                })->count_rs()->as_query(),
            'known_arrived_count'   => $self->search_related('containers', {
                    has_arrived => 1
                })->count_rs()->as_query(),
        },
    })->first();
}

=head2 human_readable_name : $pretty_pack_lane_name

The ->human_name, but actually fit for showing an end-user,
i.e. without any _ etc.

=cut

sub human_readable_name {
    my $self = shift;
    my $name = $self->human_name;
    $name =~ s/_/ /g;
    return ucfirst( $name );
}

=head2 get_packlane_description

Returns the packlane description as packlanes are referenced by
the route messaging system

=cut

sub get_packlane_description {
    return "PackLanes/". shift->human_name();
}

=head2 status_identifier

Returns the string used to identify this pack lane in pack_lane_status messages.

=cut

sub status_identifier {
    my $self = shift;
    return XT::Domain::PRLs::pack_lane_status_identifier_from_internal_name($self->internal_name)
}


1;
