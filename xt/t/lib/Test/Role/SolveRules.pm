package Test::Role::SolveRules;
use NAP::policy "tt", "role";

use Test::XT::Rules::Solve;

=head2 solve

    $retval = $self->solve( 'Rule::name', { argu => ments } );

Solves Test Rules in 'Test::XT::Rules::Solve'.

=cut

sub solve {
    my ( $self, $rule, $args )  = @_;

    return Test::XT::Rules::Solve->solve( $rule => $args );
}
