package NAP::XT::Exception::Stock::IncorrectStatusForPGIDAction;

use NAP::policy qw/tt exception/;

=head1 NAME

NAP::XT::Exception::Stock::IncorrectStatusForPGIDAction

=head1 DESCRIPTION

Thrown if an attempt is made to action a PGID with items in an incorrect state.

=head1 ATTRIBUTES

=head2 group_id

=cut

has group_id => ( is => 'ro', isa => 'Int', required => 1 );

=head2 action

=cut

has action => ( is => 'ro', isa => 'Str', required => 1 );

has '+message' => (
    default => q{PGID %{group_id}i is not in the correct status for %{action}s}
);
