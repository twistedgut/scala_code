package XTracker::Schema::ResultSet::Public::Location;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';

use XT::Domain::PRLs;
use XTracker::Config::Local qw(
    iws_location_name
    to_putaway_cancelled_location_name
    config_var
);
use XTracker::Database::Location qw( transit_location_name );

sub get_location {
    my ($self,$args_ref)=@_;

    my $location=$self->search({
        (defined $args_ref->{location_id}) ? ( id => $args_ref->{location_id} )
            : ( location => $args_ref->{location} )
        },{rows=>1})->single;

    die "Unknown location @{[ defined $args_ref->{location_id} ? ('id ',$args_ref->{location_id}) : $args_ref->{location} ]}" unless $location;

    return $location;
}

sub get_iws_location {
    return shift->get_location({ location => iws_location_name()});
}

sub get_transit_location {
    return shift->get_location({ location => transit_location_name()});
}

sub get_cancelled_location {
    return shift->get_location({
        location => to_putaway_cancelled_location_name(),
    }) || die("Internal error: No Cancelled-to-Putaway location defined\n");
}

use Scalar::Util 'blessed';

sub location_allows_status {
    my ($self,$location,$status)=@_;

    my ($id,$loc_name);

    $id=$status->id if blessed($status) && $status->can('id');
    $id=$status unless defined $id;

    $loc_name=$location->location if blessed($location) && $location->can('location');
    $loc_name=$location unless defined $loc_name;

    return $self->count({
        location => $loc_name,
        'location_allowed_statuses.status_id' => $id
    },{
        join => ['location_allowed_statuses'],
    }) > 0;

}

=head2 get_locations( \%search_params )

You can input the following keys: C<floor>, C<zone>, C<location> and C<level>.
Any values that are undefined will be replaced with C<%> in the SQL search
query.

=cut

sub get_locations {
    my ( $self, $args ) = @_;
    my $dc_loc = sprintf('%02d', config_var('DistributionCentre', 'name') =~ m{(\d+$)});
    my @location_types = ([qw<floor zone>], [qw<location level>]);
    my $params = $dc_loc . join q{-}, map {
        join q{}, map {
            $args->{$_} // q{%}
        } @$_
    } @location_types;
    return $self->search({ location => { like => $params } });
}

=head2 filter_prl

Specializes a resultset to return only locations that are really PRLs.

=cut

sub filter_prl {
    my $self = shift;

    my $prl_location_names = XT::Domain::PRLs::get_prl_location_names({
    });

    return $self->search({ location => { IN => $prl_location_names }});
}

=head2 find_by_prl($prl_name) : $location_row

Return a $location_row  for of the $prl_name. Dies if the PRL can't be found,
and dies if the location named doesn't exist.

=cut

sub find_by_prl {
    my ($self, $prl) = @_;

    return XT::Domain::PRLs::get_location_from_prl_name({
        prl_name => $prl,
    });
}

1;
