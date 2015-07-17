package Test::XTracker::Session;

use NAP::policy "tt", 'class';

=head1 NAME

Test::XTracker::Session

=head1 DESCRIPTION

Anaemic mock XT session to allow us to unit test XT session-tied code

=head1 METHODS

=cut

sub session {
    my $self = shift;

    my $session_data = { operator_id => 9999,
                         operator_name => 'Test Individual',
                         operator_username => 't.individual',
                         department_id => 8888,
                         auth_level => 3,
                       };

    return $session_data
}
