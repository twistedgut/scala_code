package XTracker::Schema::ResultSet::Public::ShippingAccountCountry;

use strict;
use warnings;

use base 'XTracker::Schema::ResultSetBase';

use Carp qw/ croak /;

=head2 find_by_country

Looks up the shipping account for country.

=cut

sub find_by_country {
    my $self = shift;
    my $country = shift || croak 'Country string required';

    return $self->search({ country => $country });
}

1;
