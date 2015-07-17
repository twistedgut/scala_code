package XTracker::Schema::ResultSet::Public::HotlistValue;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub get_all {
    my($self) = @_;
    return $self->search();
}

=head2 get_for_fraud_checking

    $array_ref  = $self->get_list_for_fraud_checking;

This will Return an ArrayRef of the following HashRefs which is the
format required for Fraud Checks to be done on the Hot List.

    [
        {
            field   => "Email",             # the name of the Field from the 'hotlist_field' table
            type    => "Customer",          # the type of the Field from the 'hotlist_type' table
            value   => "bad@address.com",   # the actual value to check against
        },
        ...
    ]

=cut

sub get_for_fraud_checking {
    my $self    = shift;;

    my $rs  = $self->get_all->search(
        {},
        {
            '+select' => [qw( hotlist_field.field hotlist_type.type )],
            '+as' => [qw( field type )],
            join => { 'hotlist_field' => 'hotlist_type' }
        }
    );

    my @hotlist = map {
        {
            field   => $_->get_column('field'),
            type    => $_->get_column('type'),
            value   => $_->get_column('value'),
        }
    } $rs->all;

    return \@hotlist;
}


1;
