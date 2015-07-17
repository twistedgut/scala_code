package XTracker::Schema::ResultSet::Public::Carrier;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Carp;

use base 'XTracker::Schema::ResultSetBase';

use XTracker::Constants::FromDB ':carrier';

=head2 find_by_name

    my $carrier = $carrier_rs->find_by_name( 'DHL Express' );

Return the first carrier row matching the country name passed in.

=cut

sub find_by_name {
    my($self,$name) = @_;

    croak 'Country name required' unless defined $name;

    return $self->search({ name => $name })->first;
}

=head2 filter_active() : $resultset|@rows

Return carriers that have shipping accounts associated with them.

=cut

sub filter_active {
    my $self = shift;

    my $me = $self->current_source_alias;
    my @carrier_columns = map { "${me}.$_" } $self->result_source->columns;

    return $self->search(
        { 'shipping_accounts.id' => { q{!=} => undef } },
        {
            join     => 'shipping_accounts',
            columns  => [@carrier_columns],
            group_by => [@carrier_columns],
        }
    );
}

=head2 filter_with_manifest() : $resultset|@rows

Return carriers that have manifests.

=cut

sub filter_with_manifest {
    my $self = shift;

    my $me = $self->current_source_alias;
    return $self->search({
        # This should probably be a column in the carrier table, but as we
        # expect changes to the schema in this part of the database with SOS, I
        # don't want to add to it - hard-coding should be fine.
        "${me}.id" => [$CARRIER__DHL_EXPRESS, $CARRIER__UPS],
    });
}

1;
