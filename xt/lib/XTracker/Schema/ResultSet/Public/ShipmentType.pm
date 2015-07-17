package XTracker::Schema::ResultSet::Public::ShipmentType;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use XTracker::Constants::FromDB qw(:shipment_type);

=head1 NAME

XTracker::Schema::ResultSet::Public::ShipmentType - DBIC resultset

=head1 DESCRIPTION

DBIx::Class resultset for shipment types

=head1 METHODS

=head2 get_premier

Returns premier shipping type

=cut

sub get_premier {
    my $self = shift;

    return $self->find({id => $SHIPMENT_TYPE__PREMIER});
}

=head2 get_international_ddu

Returns international ddu shipment type

=cut

sub get_international_ddu {
    my $self = shift;

    return $self->find({id => $SHIPMENT_TYPE__INTERNATIONAL_DDU});
}

=head2 get_dispatch_lane_config

Returns hash containing details of the configured dispatch lanes
for each shipment type.

=cut

sub get_dispatch_lane_config {
    my ( $self ) = @_;

    my $dispatch_lane_config = {};

    for my $shipment_type ($self->all) {
        # get dispatch lanes
        my @lane_numbers = $shipment_type->dispatch_lanes->get_column('lane_nr')->all;
        # note config
        $dispatch_lane_config->{ $shipment_type->id } = {
            type => $shipment_type->type,
            dispatch_lanes => {
                map { ( $_ => { lane_number => $_ } ) } @lane_numbers,
            },
        };
    }

    return $dispatch_lane_config;
}

=head1 SEE ALSO

L<XTracker::Schema>,
L<XTracker::Schema::Result::Public::ShipmentType>

=head1 AUTHOR

Pete Smith <pete.smith@net-a-porter.com>

=cut

1;


