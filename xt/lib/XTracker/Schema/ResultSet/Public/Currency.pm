package XTracker::Schema::ResultSet::Public::Currency;

use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

=head2 find_by_name

Return a C<XTracker::Schema::Result::Public::Currency> object by its name.

=cut

sub find_by_name {
    # REL-2227: stops the query falling over because of DBIx::Class upgrade
    return if ( !defined $_[1] );
    return $_[0]->find($_[1],{key=>'currency_currency_key'});
}


1;
