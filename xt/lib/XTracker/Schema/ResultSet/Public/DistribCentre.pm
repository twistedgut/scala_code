package XTracker::Schema::ResultSet::Public::DistribCentre;
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head1 find_alias( $alias )

Search for a record by alias.

NOTE: This search is case insensitive and will return only one record.

    my $dc_name = $scheme
        ->resultset('Public::DistribCentre')
        ->find_alias( 'intl' )
        ->name;

    print $dc_name;

=cut

sub find_alias {
    my ( $self, $alias ) = @_;

    die __PACKAGE__ . '->find_alias: Missing required parameter.'
        unless $alias;

    my $result = $self->search( { alias => uc $alias } );

    if ( $result->count == 1 ) {

        return $result->first;

    } else {

        warn __PACKAGE__ . '->find_alias: Search failed, zero or more than one records was returned.';
        return;

    }

}

1;

