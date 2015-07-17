package XT::Plack::Authenticate::Automated;

use NAP::policy 'class', 'tt';
with 'XTracker::Role::WithSchema';

=head1 DESCRIPTION

An authenticator that assists the automated test suite

=head1 METHODS

=head2 authenticate

Whoever the user asks to be, just say yes.

=cut

sub authenticate {
    my ($self, $user, $pass) = @_;

    # Authorisation value
    my $auth = 0;

    # The 'Application' user has an empty username and password in the
    # database. If we submit an empty string as the username we will match
    # this user, so nullify here
    $user = $user eq '' ? undef : $user;

    # Attempt to find the user in the local database
    my $operator = undef;
    if( defined $user ){
        $operator = $self->schema
                         ->resultset('Public::Operator')
                         ->search(\['lower(username) = ?', lc($user)])
                         ->slice(0,0)->single;
    }

    # The simplest fix: just say 'yup, you're ok' for whoever they ask to
    # be, as long as they exist in the local database
    if( defined $operator ){ $auth = 1 }

    return $auth;
}
