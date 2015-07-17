package XTracker::Database::Session;
use strict;
use warnings;

use Net::LDAP;
use Perl6::Export::Attrs;
use Try::Tiny;

use XTracker::Config::Local qw( authentication_source ldap_config config_var );
use XTracker::Database qw(:common);
use XTracker::Error;
use XTracker::Logfile qw( xt_logger );
use XTracker::Config::YAML;
use XTracker::Interface::LDAP;
use XTracker::DBEncode  qw( encode_it );

sub update_last_login :Export {
    my($dbh,$id) = @_;

    my $sql = qq/
UPDATE operator
SET last_login = NOW()
WHERE id = ?
    /;
    my $sth = $dbh->prepare($sql);
    $sth->execute($id);

    return;
}

### Subroutine : get_operator_id                ###
# usage        :                                  #
# description  :                                  #
# parameters   : $dbh, $username                  #
# returns      : $operatorID, $auto, $disabled, $password #

sub get_operator_id :Export(:DEFAULT) {
    my ( $dbh, $operator ) = @_;

    my $operatorID = 0;
    my $auto       = 0;
    my $disabled   = 0;
    my $password   = undef;
    my $use_ldap   = 0;

    my $qry
        = "SELECT id, auto_login, disabled, password, use_ldap FROM operator WHERE lower(username) = lower(?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($operator);

    while ( my $row = $sth->fetchrow_arrayref ) {
        $operatorID = $row->[0];
        $auto       = $row->[1];
        $disabled   = $row->[2];
        $password   = $row->[3];
        $use_ldap   = $row->[4];
    }

    return $operatorID, $auto, $disabled, $password, $use_ldap;
}

=head2 get_operator_for_username

    $hash_ref = get_operator_for_username( $dbh, $user_name );

Uses a Case Insensitive search on the 'username' field of the 'operator'
table and returns the Operator's details.

=cut

sub get_operator_for_username :Export() {
    my ( $dbh, $user_name ) = @_;

    die "No 'user_name' passed to '" . __PACKAGE__ . "::get_operator_for_username'"
                if ( !$user_name );

    my $sql =<<SQL
SELECT  op.*
FROM    operator op
WHERE   LOWER(op.username) = ?
SQL
;
    my $sth = $dbh->prepare( $sql );
    $sth->execute( lc( $user_name ) );

    my $retval;
    # there are a few duplicate users with the same
    # username (once it's been lowercased) loop round
    # all records and use the last one, this is in
    # keeping with how 'get_operator_id' works which this
    # function is copying to keep the same functionality
    foreach ( my $row = $sth->fetchrow_hashref ) {
        $retval = $row;
    }

    return $retval;
}

=head2 safe_session_name

Given an XTracker::Handler, return a printable version of the session ID
associated with it.  Cope with anything we're given.

=cut

sub safe_session_name :Export(:DEFAULT) {
    my $handler = shift;

    return '[* NO HANDLER *]' unless $handler;

    my $session_name = '[* BROKEN SESSION *]';

    eval {
        my $session = $handler && $handler->session;

        if (  $session  && exists $session->{_session_id}
                        &&        $session->{_session_id} ) {
            $session_name = $session->{_session_id};
        }
        else {
            $session_name = '[* NO SESSION *]';
        }
    };

    return $session_name;
}

1;
