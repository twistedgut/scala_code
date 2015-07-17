package XTracker::Schema::ResultSet::Public::ShippingChargeClass;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;
use Carp;

use Carp;

use base 'DBIx::Class::ResultSet';


=head2 find_by_name

    my $class = $class_rs->find_by_name( 'Air' );

Return the first class row matching the name passed in.

=cut

sub find_by_name {
    my($self,$name) = @_;

    croak 'Class name required' unless defined $name;

    return $self->search({ class => $name })->first;
}
1;
