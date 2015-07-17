package XTracker::Schema::ResultSet::Public::PackLane;
use base 'DBIx::Class::ResultSet';
use NAP::policy "tt", 'class';
use XTracker::Logfile qw( xt_logger );
use List::Util qw/max/;

=head1 NAME

XTracker::Schema::ResultSet::Public::PackLane

=head1 DESRIPTION

DBIC Resultset class for pack_lane table

=head1 METHODS

=cut

use NAP::XT::Exception::InvalidPackLaneConfig;

use XTracker::Constants::FromDB qw<
    :pack_lane_attribute
>;
use XT::Domain::PRLs;

use List::MoreUtils 'any';

# _filter_selectable_packlanes
#
# Filters the resultset to those packlanes that are valid for
# container selection
sub _filter_selectable_packlanes {
    my ($self) = @_;
    # Note that 'active' really means 'selectable', as the packlanes are
    # still in use even when this flag is off, it just means they will
    # receive no new containers
    return $self->search({
        active => 1,
    });
}

=head2 select_pack_lane (@$required_attributes)

Given a list of Pack Lane Attributes, this function returns
a single packlane that has all of those attributes, and has
the highest remaining capacity. If two potential pack lanes
meet the requirements, and both have the same capacity, the
one with the lowest pack_lane_id is returned, for consistency.

If a pack lane with all the given attributes cannot be found,
a packlane with the DEFAULT attribute will be returned instead.

If there is no pack lane with the default attribute then the
pack lane with the lowest id is returned.

=cut


sub select_pack_lane {
    my ($self, $required_attributes) = @_;

    my $logger = xt_logger(__PACKAGE__);
    $logger->debug('searching for packlane with required attributes: '
        . join(', ', $required_attributes ? @$required_attributes : ()));

    my $selectable_pack_lanes_rs = $self->_filter_selectable_packlanes()
        ->with_attributes($required_attributes);
    my $packlane = $selectable_pack_lanes_rs->_select_pack_lane_with_most_remaining_capacity();
    return $packlane if $packlane;

    return $self->get_default_pack_lane();
}

# _select_pack_lane_with_most_remaining_capacity()
#
# This will look through a resultset of packlanes and return the one with
# the highest remaining capacity.
# Note that we don't care if the packlane with the highest remaining capacity
# actually has a capacity of 0 or less, the packlane will still be returned.
# In reality, the container will just circle the conveyors until room is
# physically available
sub _select_pack_lane_with_most_remaining_capacity {
    my ($self) = @_;

    # If remaining capacities are the same, then packlane with lower primary key
    # gets priority.
    # TODO: Using the PK for ordering is evil, there should be a 'sort_by'
    # (or similar) column
    my @packlanes = $self->search(undef, {
        order_by => { -desc => 'pack_lane_id' },
    })->all();
    return undef unless @packlanes;

    my %pack_lane_remaining_capacities;
    for (@packlanes) {
        $pack_lane_remaining_capacities{$_->get_available_capacity()} = $_;
    }
    my @sorted_capacities = sort {$b <=> $a} keys %pack_lane_remaining_capacities;

    return $pack_lane_remaining_capacities{shift @sorted_capacities};
}

=head2 get_total_capacity

Returns the total capacity for the packlanes in this resultset
(excluding any 'DEFAULT' lanes)

=cut
sub get_total_capacity {
    my ($self) = @_;
    my $selectable_packlanes_rs = $self->_filter_selectable_packlanes();
    return $selectable_packlanes_rs->get_column('capacity')->sum();
}

=head2 get_remaining_capacity

Returns the remaining capacity for the packlanes in this resultset
Note that due to the fact that containers can still be assigned to
packlanes even when the remaining capacity is 0, then is it possible
for this value to be less than zero

=cut

sub get_remaining_capacity {
    my ($self) = @_;

    # Go through packlanes and get the remaining capacity for each
    my @packlanes = $self->_filter_selectable_packlanes();
    my $total_remaining_capacity = 0;
    $total_remaining_capacity += $_->get_available_capacity() for @packlanes;
    return $total_remaining_capacity;
}

=head2 get_total_container_count

Returns the amount of containers currently on the the packlanes of this
resultset

=cut

sub get_total_container_count {
    my ($self) = @_;

    # Go through packlanes and get the container count for each
    my @packlanes = $self->all();
    my $total_container_count = 0;
    $total_container_count += $_->get_containers_on_packlane_count() for @packlanes;
    return $total_container_count;
}

=head2 get_total_containers_en_route_count

=cut

sub get_total_containers_en_route_count {
    my $self = shift;

    # Go through packlanes and get the container count for each
    my @packlanes = $self->all();
    my $total_container_count = 0;
    $total_container_count += $_->get_containers_en_route_count() for @packlanes;
    return $total_container_count;
}

=head2 container_count_sum() : $total_container_count

Return the sum of the container_count for all PackLanes in the
ResultSet.

This is the count of all Containers in the PackArea, as reported by
AMQ messages from the lane scanners.

=cut

###JPL: test
sub container_count_sum {
    my $self = shift;
    $self->get_column("container_count")->sum;
}

=head2 get_pack_lane_for_errors

Returns the default pack lane if there is a routing error such as
no premier lane set when one is needed, an empty container, a
container with multiple routes defined etc.

=cut

sub get_pack_lane_for_errors {
    return shift->get_default_pack_lane(@_);
}

=head2 get_default_pack_lane

Designed to guarentee a pack lane is returned. If no default
attribute is applied to a pack lane then the one with the lowest
database id is returned.

=cut

sub get_default_pack_lane {
    my $self = shift;

    my $schema = $self->result_source->schema;
    my $logger = xt_logger(__PACKAGE__);

    my $default_pack_lane = $self->with_attributes([
        $PACK_LANE_ATTRIBUTE__DEFAULT,
    ])->_select_pack_lane_with_most_remaining_capacity();
    return $default_pack_lane if $default_pack_lane;

    $logger->warn('No DEFAULT pack lane assigned. Please configure one');

    return $schema->resultset('Public::PackLane')->search({}, {
        order_by => 'pack_lane_id',
        rows => 1
    })->single;

}

=head2 update_packlanes

Allows certain attributes of packlanes to be updated en-masse (typically these are the only attributes that will usually
be updated). If these updates would result in an invalid packlane configuration, then a NAP::XT::Exception::InvalidPackLaneConfig
exception will be thrown and the updates rolled-back.

param - $updates : Hashref of packlane ids and their new attribute values,
    where key = pack_lane_id and values = a hashref with entries:
        active : 1 to enable or 0 to disable
        is_premier : 1 to add attribute, 0 to remove
        is_sample : 1 to add attribute, 0 to remove
        is_standard : 1 to add attribute, 0 to remove
    If a possible entry is not present, its value/state-of-existence will be left as it is
=cut
sub update_packlanes {
    my ($self, $updates) = @_;
    $updates //= {};

    my $schema = $self->result_source()->schema();

    # Updates will be rolledback unless they are all valid
    $schema->txn_do(sub {
        my @packlanes = $self->search({
            pack_lane_id    => { -in => [keys %$updates] },
        });

        # First update all the packlanes with the data supplied
        for my $packlane (@packlanes) {
            my $pack_lane_updates = $updates->{$packlane->pack_lane_id()};
            $packlane->active($pack_lane_updates->{active}) if defined($pack_lane_updates->{active});
            $self->_update_attribute($packlane, $PACK_LANE_ATTRIBUTE__STANDARD, $pack_lane_updates->{is_standard});
            $self->_update_attribute($packlane, $PACK_LANE_ATTRIBUTE__PREMIER, $pack_lane_updates->{is_premier});
            $self->_update_attribute($packlane, $PACK_LANE_ATTRIBUTE__SAMPLE, $pack_lane_updates->{is_sample});
            $packlane->update();
        }

        # Then make sure this configuration is valid
        $self->_validate_configuration();
    });
    return 1;
}

sub _update_attribute {
    my ($self, $packlane, $attribute, $value) = @_;
    return unless defined($value);

    if($value) {
        # Create attribute
        $packlane->add_attribute($attribute);
    } else {
        # Remove attribute
        $packlane->remove_attribute($attribute);
    }
}

sub _validate_configuration {
    my ($self) = @_;

    # fetch all attribute links for active packlanes
    my $active = $self->_filter_selectable_packlanes->search(undef, {
        prefetch => 'pack_lanes_has_attributes'
    });

    # at least one active standard + single tote
    my $single_standard_count = $active->with_attributes([
        $PACK_LANE_ATTRIBUTE__STANDARD,
        $PACK_LANE_ATTRIBUTE__SINGLE
    ])->count();

    # at least one active standard + multitote
    my $multi_standard_count = $active->with_attributes([
        $PACK_LANE_ATTRIBUTE__STANDARD,
        $PACK_LANE_ATTRIBUTE__MULTITOTE
    ])->count();

    # at least one active premier + single tote
    my $single_premier_count = $active->with_attributes([
        $PACK_LANE_ATTRIBUTE__PREMIER,
        $PACK_LANE_ATTRIBUTE__SINGLE,
    ])->count();

    # etc etc...
    my $multi_premier_count = $active->with_attributes([
        $PACK_LANE_ATTRIBUTE__PREMIER,
        $PACK_LANE_ATTRIBUTE__MULTITOTE,
    ])->count();

    my $single_sample_count = $active->with_attributes([
        $PACK_LANE_ATTRIBUTE__SAMPLE,
        $PACK_LANE_ATTRIBUTE__SINGLE
    ])->count();

    my $multi_sample_count = $active->with_attributes([
        $PACK_LANE_ATTRIBUTE__SAMPLE,
        $PACK_LANE_ATTRIBUTE__MULTITOTE
    ])->count();

    # ensure if a lane is activated, the user has explictly
    # configured something to go there.

    my $active_unassigned_count = 0;

    my @check_attrs = (
        $PACK_LANE_ATTRIBUTE__STANDARD,
        $PACK_LANE_ATTRIBUTE__PREMIER,
        $PACK_LANE_ATTRIBUTE__SAMPLE
    );

    foreach my $lane ($active->all) {

        my $attrs = $lane->get_attribute_ids();

        if (! any { exists($attrs->{$_}) } @check_attrs) {
            $active_unassigned_count++
        }
    }

    NAP::XT::Exception::InvalidPackLaneConfig->throw({
        has_no_single_tote_standard => ($single_standard_count ? 0 : 1),
        has_no_multi_tote_standard  => ($multi_standard_count ? 0 : 1),
        has_no_single_tote_premier  => ($single_premier_count ? 0 : 1),
        has_no_multi_tote_premier   => ($multi_premier_count ? 0 : 1),
        has_no_single_tote_sample   => ($single_sample_count ? 0 : 1),
        has_no_multi_tote_sample    => ($multi_sample_count ? 0 : 1),
        has_active_unassigned       => ($active_unassigned_count ? 1 : 0)
    }) unless (
        $single_standard_count
     && $multi_standard_count
     && $single_premier_count
     && $multi_premier_count
     && $single_sample_count
     && $multi_sample_count
     && !$active_unassigned_count
    );

    return 1;
}

=head2 with_attributes

Filters the resultset to include only those packlanes that have the listed attributes assigned

param - $attribute_ids : An array ref of attribute_ids (as db.pack_lane_attribute.pack_lane_attribute_id)
    that identify what attributes the packlanes should have

return - As DBIx::Class::ResultSet->search() (context sensitive)

=cut

sub with_attributes {
    my ($self, $attribute_ids) = @_;
    return $self->_search_by_attributes($attribute_ids, '-in');
}

=head2 without_attributes

Filters the resultset to include only those packlanes that do not have the listed attributes assigned

param - $attribute_ids : An array ref of attribute_ids (as db.pack_lane_attribute.pack_lane_attribute_id)
    that identify what attributes the packlanes should not have

return - As DBIx::Class::ResultSet->search() (context sensitive)

=cut

sub without_attributes {
    my ($self, $attribute_ids) = @_;
    return $self->_search_by_attributes($attribute_ids, '-not_in');
}

sub _search_by_attributes {
    my ($self, $attribute_ids, $operator) = @_;
    $attribute_ids //= [];
    my $attribute_queries = {};

    # Create a sub-query for each attribute we need by searching for pack_lane_ids in
    # the pack_lane_has_attribute table
    my $schema = $self->result_source()->schema();
    for my $attribute_id (@$attribute_ids) {
        $attribute_queries->{$attribute_id} = $schema->resultset('Public::PackLaneHasAttribute')->search({
            pack_lane_attribute_id => $attribute_id,
        })->get_column('pack_lane_id')->as_query();
    }
    my @search = map { ('pack_lane_id' => { $operator => $attribute_queries->{$_} }) } keys %$attribute_queries;
    return $self->search({ -and => \@search });
}

=head2 packlanes_and_containers

Returns the pack lanes in the resultset, sorted for nice display and with their
containers prefetched.

=cut

sub packlanes_and_containers {
    my ($self) = @_;

    return $self->search( undef,
                          { order_by => 'me.human_name',
                            prefetch => 'containers',
                          }
                        );
}

=head2 find_by_status_identifier

Finds a pack lane by the string used in pack_lane_status messages.

=cut

sub find_by_status_identifier {
    my $self = shift;
    my $status_identifier = shift;

    return $self->search({
        internal_name => XT::Domain::PRLs::pack_lane_internal_name_from_status_identifier($status_identifier)
    })->single;
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);

1;
