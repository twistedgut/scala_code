package XT::Plack::Authenticate;

use NAP::policy 'class', 'tt';

=head1 DESCRIPTION

An authenticator that checks each NAP LDAP server in turn

=cut

use XTracker::Interface::LDAP;
use XTracker::Logfile       qw( xt_logger );

=head1 METHODS

=head2 authenticate

Check each LDAP server and return 1 on successful bind using username and
password. Failure to bind returns 0.

=cut

sub authenticate {
    my ($self, $user, $pass) = @_;

    my $auth = 0;
    try {
        my $ldap = XTracker::Interface::LDAP->new();
        $ldap->connect;

        if ( $ldap->authenticate($user, $pass) ) {
            $auth = 1;
        }
    }
    catch {
        xt_logger->warn( "Unable to authenticate using LDAP - $_" );
    };

    return $auth;
}
