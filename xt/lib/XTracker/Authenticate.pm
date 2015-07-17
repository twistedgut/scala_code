package XTracker::Authenticate;
use NAP::policy 'tt';

use Plack::App::FakeApache1::Constants qw(:common);

use URI::Escape;
use HTTP::Status qw(:constants);

use XTracker::Config::Local     qw( :DEFAULT should_authentication_respond_to_an_ajax_request );
use XTracker::Database qw(read_handle get_database_handle);
use XTracker::Database::Profile qw(get_operator get_operator_preferences);
use XTracker::Logfile qw( xt_logger );
use XTracker::Session;
use XTracker::Database::Session ();
use XTracker::Error;
use Scalar::Util qw/blessed/;
use XTracker::RAVNI_transient 'maybe_kill_ravni';
use XTracker::PRLPages 'is_prl_disabled_section';
use XTracker::Interface::LDAP;
use XTracker::Utilities     qw( parse_url_path );
use XTracker::DBEncode      qw( encode_it );

use XT::AccessControls;


sub handler {
    my $r = shift;

    given ($r) {
        when ($_->isa('Plack::App::FakeModPerl1')) {
            return handler__plack($r);
        }

        default {
            die 'Unknown Authenticate object ' . ref($r);
        }
    }

    return;
}

sub handler__plack {
    my $plack = shift;
    my $session = XTracker::Session->session();
    # there's no excuse for not having a session!
    if (not defined $session) {
        die q{NO SESSION!};
    }

    # Determine whether we're in handheld view right away
    $session->{is_handheld} = _is_handheld($plack->parsed_uri);

    # if the user isn't logged in ... bounce off to the login page
    if (not exists $session->{user_id}) {
        # store where they were trying to get to
        $session->{redir_to} = $plack->{request}->path;
        # See: http://en.wikipedia.org/wiki/List_of_HTTP_status_codes#3xx_Redirection
        $plack->{response}->redirect( $session->{is_handheld} ? '/HandHeld' : '/Login', HTTP_SEE_OTHER);
        return REDIRECT;
    }

    # TODO: fetch operator information
    if (not defined $session->{operator_name}) {
        _store_opdata_in_session($session);
    }

    # if the user is logged in but doesn't have operator information there's
    # something very strange going on
    if (not exists $session->{operator_name}) {
        xt_die('Operator Data Missing');
        return _redirect_to_home_screen($plack, $session->{is_handheld});
    }

    # check to see if we have any operator preferences stored in the session, get some if not
    if (not defined $session->{op_prefs} ) {
        _store_opprefs_in_session($session);
    }

    if (not _acl_check($plack)) {
        # BUG - xt_warn() message is lost in the redirect fallback to xt_die()
        xt_logger('UserAccess')->warn("ACCESS DENIED: SECTION=\"".$session->{section}."/".$session->{subsection}."\" "
                    .'OPERATOR_ID='.($session->{operator_username} // "[* UNKNOWN OPERATOR *]")." "
                    .'USER='.($session->{operator_username} // "[* UNKNOWN OPERATOR *]")." "
                    .'SESSION='.($session->{_session_id}//'[* NO SESSION *]')
                 );
        xt_die( qq{You don't have permission to access $session->{subsection} in $session->{section}.} );
        return _redirect_to_home_screen($plack, $session->{is_handheld});
    }

    # Set the unread messages notification
    my $schema = get_database_handle( { name => 'xtracker_schema' } );

    $session->{application}{messages}{unread} =
        $schema->resultset('Operator::Message')->unread_message_count( {
            recipient_id => $session->{operator_id}
        } );

    # yes, a copy-paste-hack from the mod_perl flow
    if (maybe_kill_ravni($plack,undef,$session->{section},$session->{subsection})
            || is_prl_disabled_section($plack,undef,$session->{section},$session->{subsection})) {
    }

    if (my $just_logged_in = delete $session->{'nap.just.authenticated'}) {
        # Execute the post-login steps from old Login.pm
        my $dbh = read_handle();

        # Ensure that the user DB record has correct email address per LDAP
        _update_email_from_ldap( $dbh, $session );

        # Update last login timestamp
        XTracker::Database::Session::update_last_login($dbh,
                                                       $session->{operator_id});

        # this is our chance to take people to their preferred page
        # we'll only do this if they're trying to hit / or /Home
        # (or handheld equivalents)
        # If the URL is slightly more interesting there's a really strong
        # chance they were trying to get somewhere specific but didn't have an
        # active session
        given ($plack->{request}->path) {
            _try_preferred_page($plack)
                when '/';
            _try_preferred_page($plack)
                when '/Home';
            _try_preferred_page($plack)
                when '/HandHeld';
            _try_preferred_page($plack)
                when '/HandHeld/Home';

            default {
                # don't interfere
            }
        }
    }

    return OK;
}

sub _try_preferred_page {
    my $plack = shift;
    my $session = XTracker::Session->session();
    if (my $preferred_home = $session->{op_prefs}{default_home_url}) {
        $plack->{response}->redirect($preferred_home, HTTP_SEE_OTHER);
    }
    return;
}

sub _set_current_section {
    my $plack   = shift;
    my $session = XTracker::Session->session();

    my ( $url_path, $current_section, $current_sub_section ) = _current_section_info($plack);
    $session->{section} = $current_section;
    $session->{subsection}  = $current_sub_section;
    if (defined $current_sub_section and $current_sub_section !~ m{\A\s*\z}) {
        $session->{current_sub_section} =
              $current_sub_section
            . q{ &#8226; }
            . $current_section
        ;
    }
    else {
        delete $session->{current_sub_section};
    }

    return $url_path;
}

sub _acl_check {
    my $request_object  = shift;
    my $session         = XTracker::Session->session();

    my $authorised_ok = 0;
    # make sure we don't have anything from previous auths
    delete $session->{auth_level};
    delete $session->{department_id};
    delete $session->{acl}{authorisation_granted};

    # sets the Section, Sub-Section & returns the URL Path of the request
    my $url_path = _set_current_section($request_object);

    my $schema = get_database_handle( {
        name => 'xtracker_schema',
    } );

    # if we don't have a current section, there's nothing to validate against
    if ( (not $session->{section}) || ('Home' eq $session->{section}) || ('My' eq $session->{section}) ) {
        $authorised_ok = 1;
        # we need to get the user's department ID even if there's no section
        $session->{department_id} =
            XTracker::Database::Profile::get_department_id(
                $session->{operator_id}
            );
    }

    # we can always view the Home screen (on a handheld) once we're logged in
    elsif ($session->{is_handheld} and ('Home' eq $session->{subsection})) {
        $authorised_ok = 1;
    }

    # otherwise we need a non-zero auth-level
    else {
        my $status_ok;
        # get auth_level and dept_id information
        eval {
            my $acl = XT::AccessControls->new( {
                operator => $schema->resultset('Public::Operator')->find( $session->{operator_id} ),
                session  => $session,
            } );

            $status_ok = $acl->has_permission( $url_path, {
                update_session   => 1,
                can_use_fallback => 1,
            } );
        };

        if ( my $error = $@ ) {
            warn "Problem with retrieving authentication info: ${error}";
        }

        # TODO - rework this to be more sensible and easy to comprehend
        if (not $status_ok) {
            # user not authorised. Return 0 so they get redirected to home page.
            return 0;
        }

        # if we have a non-zero auth_level, we're OK to view the section
        if ( (defined $session->{auth_level} and ($session->{auth_level} > 0)) || ( delete $session->{acl}{authorisation_granted} ) ) {
            $authorised_ok = 1;
        }
    }

    return $authorised_ok;
}

### Subroutine : _critical_error                ###
# usage        :                                  #
# description  :                                  #
# parameters   : $r,$message                      #
# returns      : undefined-value                  #
sub _critical_error {
    my ($r, $message) = @_;

    # make sure we have something in the logs
    xt_logger->error( $message );

    # put something into the user's browser
    $r->print( encode_it(
          $message
        . qq{\nThis is a critical error.\nPlease inform the XT support team at: }
        . XTracker::Config::Local->xtadmin_email()
    ) );

    return;
}

### Subroutine : _current_section_name          ###
# usage        :                                  #
# description  :                                  #
# parameters   : $r                               #
# returns      : $current_section                 #
sub _current_section_info {
    my $r   = shift;

    my $uri         = $r->parsed_uri;
    my $path_info   = $uri->path;

    my $path_parsed = parse_url_path( $path_info );
    my $section     = $path_parsed->{section};
    my $sub_section = $path_parsed->{sub_section};

    if ( !defined $section || !defined $sub_section ) {
        return $path_info;
    }

    return ( $path_info, $section, $sub_section );
}

sub _is_handheld {
    my $uri = shift;

    # We have two ways of determining whether we're in a handheld view:
    # * The URL's path starts with /Handheld
    # * We pass a view parameter of 'HandHeld'
    my @levels = split  /\//, $uri->path;
    my %params = $uri->query_form;

    # NOTE: I don't think case-sensitivity is a 'feature' here, look at making
    # this case insensitive.
    return scalar grep { $_ && $_ eq 'HandHeld' } $levels[1], $params{view};
}

### Subroutine : _is_logged_in                  ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      : 0 or 1                           #
sub _is_logged_in {
    my $session = shift;

    # someone is logged in if they have a session, and that session contains an
    # operator ID
    if (defined $session and defined $session->{operator_id}) {
#        xt_logger->debug(
#            q{session exists AND operator_id found - LOGGED IN}
#        );
        return 1;
    }

    # no, not logged in
#    xt_logger->debug(
#        q{NOT LOGGED IN}
#    );
    return 0;
}

### Subroutine : _redirect_to_home_screen       ###
# usage        :                                  #
# description  :                                  #
# parameters   : $r, $handheld                    #
# returns      : undefined-value                  #
sub _redirect_to_home_screen {
    my ($r, $is_handheld) = @_;

    # set the page to redirect to based on whether we're handheld or not
    given ($r) {
        when ($_->isa('Plack::App::FakeModPerl1')) {
            if ($is_handheld) {
                $r->{response}->redirect("/HandHeld/Home");
            } else {
                $r->{response}->redirect("/Home");
            }
        }
    }

    return REDIRECT;
}

# this is the plackified lookup where wer get user_id from the Auth middleware
# NOTE: LDAP's user_id is the user's login/network name
sub _store_opdata_in_session {
    my $session = shift;
    my $dbh = read_handle();

    return
        unless defined $session->{user_id};

    use XTracker::Database::Session     qw( get_operator_for_username );
    my $opdata = get_operator_for_username( $dbh, $session->{user_id} );

    return
        unless $opdata;

    # store useful/required information in the session
    $session->{operator_id}         = $opdata->{id};
    $session->{operator_name}       = $opdata->{name};
    $session->{operator_username}   = $opdata->{username};

    return;
}

sub _store_opprefs_in_session {
    my ($session) = @_;
    my ($dbh);

    # use the read-only database handle
    $dbh = read_handle();

    # if we have an operator(id) then fetch their preferences!
    if (defined $session->{operator_id} and $session->{operator_id} > 0) {

        my $prefs = get_operator_preferences($dbh,$session->{operator_id});
        $session->{op_prefs} = $prefs;
    }
}

=head2 _update_email_from_ldap

The users email address field in the XT database may be set as 'Not set in
LDAP'. If this is the case replace this with the email address from Active
Directory

=cut

sub _update_email_from_ldap {
    my ($dbh, $session) = @_;

    my $updated = 0;

    my $operator_id = $session->{operator_id};

    # We do not want to leave the email address in the session
    my $email = delete $session->{operator_email_address};
    return $updated unless ( defined $email && $email ne '' );

    my $sql = 'SELECT email_address FROM operator WHERE id = ?';

    my $sth = $dbh->prepare($sql);
    $sth->execute( $operator_id );

    if ( my $user_email = $sth->fetchrow() ) {
        if ($user_email eq 'Not set in LDAP') {
            $sql = 'UPDATE operator SET email_address = ? WHERE id = ?';
            my $sth = $dbh->prepare($sql);
            $sth->execute($email,$operator_id);
            $updated = 1;
        }
    }

    return($updated);
}

1;
