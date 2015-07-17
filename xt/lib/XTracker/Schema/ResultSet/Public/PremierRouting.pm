=pod

=head1 NAME

    XTracker::Schema::ResultSet::Public::PremierRouting

=head1 DESCRIPTION

    ResultSet class for Public::PremierRouting

=head1 METHODS

=over 4

=cut

package XTracker::Schema::ResultSet::Public::PremierRouting;
use strict;
use warnings;
use base 'DBIx::Class::ResultSet';


=item undef|XTracker::Schema::Result::Public::PremierRouting find_code(str)

Return the row for the premier routing code passed in

=cut

sub find_code {
    my ($self,$code) = @_;

    return $self->find({
        code => $code
    });
}

=back

=head1 AUTHOR

    Jason Tang <jason.tang@net-a-porter.com>

=cut

1;
