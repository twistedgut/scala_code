package XTracker::Login;
use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);
use Digest::MD5;
use XTracker::Handler;
use XTracker::Config::Local             qw( config_var );
use Data::Dump                          qw{ dump pp };
use XTracker::Database::Session;
use XTracker::Database::Profile         qw( get_operator_preferences );
use XTracker::Logfile                   qw( xt_logger );
use XTracker::Session;
use XTracker::Error;
use XTracker::Utilities                 qw( :string );
use URI::Escape;

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # initialise error message
    my $error = delete( $handler->{session}{error}{message} );
    my $param_uri   = $handler->{param_of}{'uri'};
    my $param       = uri_unescape( $handler->{param_of}{'param'} );
    my @params;
    @params = split( /\|/, $param ) if $param;
    my $param_get   = "";

    foreach my $par (@params) {
        my ( $key, $value ) = split( /=/, $par );
        $param_get .= "$key=$value&amp;";
    }

    # get url
    my @levels    = split /\//, $handler->{data}{uri};

    # check for hand held log in
    my $handheld = 0;
    if ( $levels[1] ) {
        if ( $levels[1] eq "HandHeld" || $levels[1] eq "HandHeldMigration" ) {
            $handheld = 1;
        }
    }

    # ok, if you're already logged in, it's bloody stupid to try to login
    # again; redirect logged-in users straight to (/HandHeld)/Home
    if ( $handler->operator_id ) {
        if ( $handheld == 1 ) {
            return $handler->redirect_to("/HandHeld/Home");
        }
        else {
            return $handler->redirect_to("/Home");
        }
    }

    # get username if entered, and the redirect used if the session expires
    my $username = trim( $handler->{param_of}{'username'} );

    # form submitted
    if ( $username ) {
        my ($login_ok,$mesg)    = _log_user_in($handler,$username,$handheld,\$param_get);
        if ($login_ok) {
            return $handler->redirect_to($mesg);
        }
        else {
            $error .= $mesg;
        }
    }

    # login form
    $handler->{data}{content}   = 'login.tt';
    $handler->{data}{section}   = 'Login';
    $handler->{data}{title2}    = '';
    $handler->{data}{title3}    = '';
    $handler->{data}{sidenav}   = {};
    $handler->{data}{uri}       = $param_uri;
    $handler->{data}{get}       = $param_get;

    #$handler->{data}{error_msg}= $error;
    $handler->{data}{handheld}  = $handheld;

    # if we have an error, use it
    if ( defined $error ) {
        xt_warn($error);
    }

    if ( $handheld == 1 ) {
        $handler->{data}{view}  = "HandHeld";
    }

    $handler->process_template( undef );

    return OK;
}

### Subroutine : _log_user_in                                                    ###
# usage        : ($login_ok,$mesg)=log_user_in(                                    #
#                      $handler_ref,$username,$handheld,$param_get_ref)            #
# description  : Actually log's the user in, Returns an ok flag set to true if     #
#                user has logged in successfully along with the URL to redirect to #
# parameters   : Reference to a Handler Object, the user name passed in the form   #
#                & whether the user is using a handheld device.                    #

sub _log_user_in {
    my ($handler,$username,$handheld,$param_get)        = @_;

    my $logger = xt_logger( qw( UserLogin ) );

    my $error       = "";
    my $redir_url   = "";
    my $login_ok    = 1;

    # prefix for the 'logger' when 'Login'
    # was done via an AJAX request
    my $ajax_log_prefix = ( $handler->was_sent_ajax_header ? 'AJAX ' : '' );

    # get operator ID and check if auto-login
    my ( $operatorID, $auto, $disabled, $password, $use_ldap )  = get_operator_id( $handler->{dbh}, $username );

    # Operator found in DB
    if ( $operatorID != 0 ) {
        if ( $disabled == 0 ) {

            my $is_authorised   = undef; # none zero or undef is false
            my $ldap_email = '';
            my $ldap_groups;

            # auto login - don't authenticate against NT
            if ( $auto == 1 ) {
                $is_authorised = 1;
            }
            else {
                # not auto login - authenticate against NT
                # debatably, we ought to trim the password that's been entered too, but we don't yet
                ($is_authorised,$ldap_email,$ldap_groups) = check_login( $handler->{dbh}, $username, $handler->{param_of}{'pass'}, $use_ldap );
            }
            # login authenticated OK
            if ( $is_authorised ) {
                warn "***** DEPRECATED XTracker::Login called for authentication! *****";
                # store the operator id in the session (this counts as logged in)
                $handler->session->{operator_id} = $operatorID;

                # store the user roles in session ,( acl - access Control list )
                $handler->session->{acl}{operator_roles} = $ldap_groups;

                # TP-579 - force write to avoid race condition when redirect comes in on different process
                # and reads session before this session moves out of scope and writes automatically.
                #tied(%{$handler->session})->save;
                XTracker::Database::Session::update_last_login($handler->{dbh},$operatorID);

                my $session_name = safe_session_name( $handler );

                if ( $auto == 1 ) {
                    $logger->info( "${ajax_log_prefix}AUTO-LOGIN: USER=$username SESSION=$session_name\n" );
                }
                else {
                    $logger->info(      "${ajax_log_prefix}LOGIN: USER=$username SESSION=$session_name\n" );
                }

                $$param_get = $handler->{param_of}{'get'};

                # now redirect to overview page
                if ( $handheld == 1 ) {
                    if ( not defined $handler->session->{handheld} ) {
                        $handler->session->{handheld} = 1;
                    }

                    # were we trying to get somewhere before we got
                    # pushed through the login screen?
                    if (defined $handler->session->{after_login}) {
                        $redir_url  = delete($handler->session->{after_login});
                    }
                    else {
                        $redir_url  = "/HandHeld/Home"
                    }
                }
                else {
                    if ( not defined $handler->session->{handheld} ) {
                        $handler->session->{handheld} = 0;
                    }

                    # were we trying to get somewhere before we got
                    # pushed through the login screen?
                    if (defined $handler->session->{after_login}) {
                        $redir_url  = delete($handler->session->{after_login});
                    }
                    else {
                        # See if there is a Default Home Page Set
                        my $prefs   = get_operator_preferences($handler->{dbh},$operatorID);
                        ## no critic(ProhibitDeepNests)
                        if ( defined $prefs
                                and defined $prefs->{default_home_url}
                                and $prefs->{default_home_url} ne "" ) {

                            $redir_url  = $prefs->{default_home_url};
                        }
                        else {
                            $redir_url  = "/Home";
                        }
                    }

                    ## TODO-PSGI: The updating of the email address from LDAP
                    ## looks like it should be executed on a successful
                    ## login. Check that this is the case as we've changed the
                    ## eval branch logic a bit here

                    # check email address
                    if (defined $ldap_email && $ldap_email ne '') {
                        xt_info("Email address updated from LDAP to $ldap_email") if _check_user_email($handler->{dbh}, $operatorID, $ldap_email);
                    }
                }
            }
            else {
                # login not authenticated against NT
                $logger->warn( "${ajax_log_prefix}LOGIN DENIED: USER=$username SESSION=".safe_session_name($handler)." LOGIN INCORRECT\n" );

                $login_ok       = 0;
                $error
                .= 'Sorry, your login details were incorrect, please try again.<br /><br />Please note if your Windows password has expired or is due to expire you will need to reset it before logging into xTracker with the new password.';
            }
        }
        else {
            $logger->warn( "${ajax_log_prefix}LOGIN DENIED: USER=$username SESSION=".safe_session_name($handler)." DISABLED\n" );

            $login_ok       = 0;
            $error .=
            q{Sorry, your account has been disabled, please contact }
            . config_var('Email', 'xtracker_email')
            . q{ for assistance. }
            . q{Please quote this error message in your communications.}
        }
    }
    else {
        # operator NOT found in DB

        $logger->warn( "${ajax_log_prefix}LOGIN DENIED: USER=$username SESSION=".safe_session_name($handler)." USER NOT FOUND\n" );

        $login_ok       = 0;
        $error
        .= 'Sorry, you were not found on the system, please contact the IT department for help.';
    }

    if ($login_ok) {
        return ($login_ok,$redir_url);
    }
    else {
        return ($login_ok,$error);
    }
}


sub _check_user_email {
    my ($dbh, $operator_id, $ldap_email) = @_;
    my $updated = 0;

    my $sql = 'SELECT email_address FROM operator WHERE id = ?';

    my $sth = $dbh->prepare($sql);
    $sth->execute( $operator_id );

    if ( my $user_email = $sth->fetchrow() ) {
        if ($user_email eq 'Not set in LDAP') {
            $sql = 'UPDATE operator SET email_address = ? WHERE id = ?';
            my $sth = $dbh->prepare($sql);
            $sth->execute($ldap_email,$operator_id);
            $updated = 1;
        }
    }

    return($updated);
}

1;
