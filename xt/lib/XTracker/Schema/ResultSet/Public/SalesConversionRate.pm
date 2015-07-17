package XTracker::Schema::ResultSet::Public::SalesConversionRate;
# vim: set ts=4 sw=4 sts=4:

use strict;
use warnings;

use Carp qw/ croak /;

use base 'DBIx::Class::ResultSet';

sub conversion_rate {
    my($self,$from,$to) = @_;

    $self->search(
        {
            source_currency      => $from,
            destination_currency => $to,
        },
        {
            order_by => { -desc => 'date_start' },
        },
    )->first->conversion_rate;
}

1;
