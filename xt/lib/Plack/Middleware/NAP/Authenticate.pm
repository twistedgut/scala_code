package Plack::Middleware::NAP::Authenticate;
# NAP::policy 0.0.4 causes problems with Plack::Util::Accessor
use strict;
use warnings;
use feature ':5.10';

use parent qw/Plack::Middleware/;
use Plack::Util::Accessor qw( secure authenticator no_login_page after_logout ssl_port plack_request plack_session);
use Plack::Request;
use Plack::Session;
use Scalar::Util;
use HTTP::Status qw(:constants);
use Carp ();
use Try::Tiny;
use XTracker::Config::Local 'config_var';
use XTracker::Interface::LDAP;
use XTracker::Logfile 'xt_logger';
use XTracker::Interface::LDAP;
use XT::AccessControls::InsecurePaths 'permitted_insecure_path';

sub prepare_app {
    my $self = shift;

    # fallback to the NAP default authentication if someone hasn't decided to
    # do something different
    $self->_set_default_authenticator
        if not $self->authenticator;

    my $auth = $self->authenticator or Carp::croak 'authenticator is not set';
    if (Scalar::Util::blessed($auth) && $auth->can('authenticate')) {
        $self->authenticator(sub { $auth->authenticate(@_[0,1]) }); # because Authen::Simple barfs on 3 params
    } elsif (ref $auth ne 'CODE') {
        die 'authenticator should be a code reference or an object that responds to authenticate()';
    }
}

sub _set_default_authenticator {
    my $self = shift;
    require XT::Plack::Authenticate;
    my $ldap = XT::Plack::Authenticate->new();
    $self->authenticator($ldap);
    return;
}

sub call {
    my($self, $env) = @_;
    my $path = $env->{PATH_INFO};

    $self->plack_request(
        Plack::Request->new( $env )
    );

    # slightly icky, but we were already doing it like this later in the module
    # when we clean it up later it'll just be in one place
    $self->plack_session( Plack::Session->new($env) );
    my $session = $self->plack_session;

    # If the user account is disabled just render the login page
    return $self->_login( $env ) if $session->get('disabled_account');

    # we need to cater for the /HandHeld loging URL
    # - yeah, silly, but it's been this way for years, so we'll continue to
    # leave this as a future task
    my $login_path_re  = qr{\A/(?:[Ll]ogin|HandHeld)/?\z};
    my $logout_path_re = qr{\A/[Ll]ogout/?\z};

    if( $session->get('remember') ){
        if( $path !~ m{$logout_path_re} ){
            $env->{'psgix.session.options'}{expires} = time + 60 * 60 * 24 * 30;
        }
        $session->remove('remember');
    }

    if( $path =~ m{$login_path_re} ){
        return $self->_login( $env );
    }
    elsif( $path =~ m{$logout_path_re} ){
        return $self->_logout( $env );
    }
    elsif ( ! $self->looks_like_ajax &&
            ! permitted_insecure_path( $path ) &&
            ! $session->get('user_id') ) {
        return $self->_login( $env );
    }
    else {
        if ($self->looks_like_ajax and  not defined $session->get('user_id') ){
            xt_logger->warn('AJAX Request Not Authorized');
            return $self->empty_response_with_status(HTTP_UNAUTHORIZED);
        }
    }

    return $self->app->( $env );
}

sub empty_response_with_status {
    my $self = shift;
    my $http_status = shift;

    return Plack::Response->new( $http_status )->finalize;
}

## cribbed from CANDO-2117 commits
sub allow_ajax_by_referer {
    my $self  = shift;

    # if not called by an AJAX request then return FALSE
    return 0        unless ( $self->looks_like_ajax );

    # get a list of URLs that are valid
    my $ajax_uris   = config_var('AJAXLoginRefererURL', 'url');
    $ajax_uris      = ( ref( $ajax_uris ) ? $ajax_uris : [ $ajax_uris ] );

    # get the Referer
    my $referer     = $self->plack_request->referer // '';

    return ( scalar( grep { $referer =~ m/\Q${_}\E/ } @{ $ajax_uris } ) ? 1 : 0 );
}

sub looks_like_ajax {
    my $self  = shift;
    my $header  = $self->plack_request->headers->header('X-Requested-With') // '';
    return ( lc( $header ) eq 'xmlhttprequest' ? 1 : 0 );
}
## END CANDO cribbing

sub response_with_logged_in_user {
    my ($self, $env, $content) = @_;

    my $redir_to = $self->plack_session->remove('redir_to') //
        ( $self->_is_handheld($env) ? '/HandHeld/Home' : '/Home' );

    # via AJAX ? set JSON header, return OK : redirect to /Home
    if ($self->allow_ajax_by_referer) {
        return $self->empty_response_with_status(HTTP_OK);
    }

    # regular browser behaviour
    $redir_to = '/' if
        URI->new( $redir_to )->path eq $self->plack_request->env->{PATH_INFO};
    return [
        HTTP_SEE_OTHER,
        [ Location => $redir_to ],
        [ $content // () ]
    ];
}

sub _is_handheld {
    my($self, $env) = @_;
    return !! ( $env->{REQUEST_URI} =~ m{^/HandHeld|view=HandHeld} );
}

sub _login {
    my($self, $env) = @_;
    my $handheld_login = 0;
    my $session = $self->plack_session;
    my $logger = xt_logger('UserLogin');
    my $ajax_log_prefix = ( $self->looks_like_ajax ? 'AJAX ' : '' );

    if ( $session->get('disabled_account') ) {
        $self->_expire_session($session);
    }
    my $login_error;
    if( $self->secure
        && ( !defined $env->{'psgi.url_scheme'} || lc $env->{'psgi.url_scheme'} ne 'https' )
        && ( !defined $env->{HTTP_X_FORWARDED_PROTO} || lc $env->{HTTP_X_FORWARDED_PROTO} ne 'https' )
    ){
        my $server = $env->{HTTP_X_FORWARDED_FOR} || $env->{HTTP_X_HOST} || $env->{SERVER_NAME};
        my $secure_url = "https://$server" . ( $self->ssl_port ? ':' . $self->ssl_port : '' ) . $env->{PATH_INFO};
        return [
            HTTP_SEE_OTHER,
            [ Location => $secure_url ],
            [ $self->_wrap_body( "<a href=\"$secure_url\">Need a secure connection</a>" ) ]
        ];
    }

    #my $request = Plack::Request->new( $env );
    my $source_ip = $env->{HTTP_X_FORWARDED_FOR} || "0.0.0.0";
    my $request = $self->plack_request;
    my $params  = $request->parameters;

    if( defined $session->get('user_id') ){
        return $self->response_with_logged_in_user($env);
    }

    # login details have been posted to us
    elsif( $env->{REQUEST_METHOD} eq 'POST' ){
        my $user_id;

        # let people know they've used DEPRECATED 'pass'
        my $password;
        if ($password = $params->get('pass')) {
            warn(
                'DEPRECATED use of "pass" parameter; referer='
                . $request->referer
            );
        }
        else {
            $password = $params->get('password');
        }

        my $auth_result = $self->authenticator->( $params->get( 'username' ), $password, $env );

        if( ref $auth_result ){
            $login_error = $auth_result->{error};
            $user_id = $auth_result->{user_id};
        }
        else{
            $login_error = 'Wrong username or password' if !$auth_result;
            $user_id = $params->get( 'username' );
        }
        # authenticated successfully
        if( !$login_error ){
            $session->set('user_id', $user_id);
            $session->set('nap.just.authenticated', 1);

            my $user_attributes;
            try {
                my $ldap = XTracker::Interface::LDAP->new();
                $user_attributes = $ldap->get_user_attributes($params->get('username'));
            }
            catch {
                xt_logger->warn("Unable to get user attributes from LDAP - $_");
            };
            $session->set('acl', {
                    operator_roles => $user_attributes->{groups},
                } );

            # This session key is removed in the XTracker::Authenticate
            # _update_email_from_ldap method. Do not expect it to be available.
            $session->set('operator_email_address', $user_attributes->{email});

            $session->set('remember', 1) if $params->get( 'remember' );

            $logger->info($ajax_log_prefix
                          . "LOGIN: USER=$user_id "
                          . 'SESSION=' . $session->id . ' '
                          . 'SOURCE_IP=' . $source_ip );

            return $self->response_with_logged_in_user(
                $env,
                $self->_wrap_body(
                    sprintf('<a href="%s">Back</a>', $session->get('redir_to') // '')
                )
            )
        }
        else {
            $logger->info($ajax_log_prefix
                          . "LOGIN DENIED: USER=$user_id "
                          . 'SESSION=' . $session->id . ' '
                          . 'SOURCE_IP=' . $source_ip . ' '
                          . q{"} . uc($login_error) . q{"} );
        }
    }

    # getting here means we've either tried to log in and screwed it up
    # or we're not POSTing anything at all and would like to see the login screen
    # (GET /Login)

    # ajax requests ONLY want to know they messed up, they don't want the
    # login page
    if ($self->allow_ajax_by_referer) {
        return $self->empty_response_with_status(HTTP_UNAUTHORIZED);
    }

    # are we doing a 'handheld login'?
    $handheld_login = $self->_is_handheld($env);

    # support /HandHeld as a log URL that 'keeps' the use in /HandHeld land
    $session->set('redir_to',
        $handheld_login ?
            '/HandHeld/Home' :
            $session->get('redir_to') || $env->{HTTP_REFERER} || '/Home'
    );

    my $form = $self->_render_form(
        username => $params->get( 'username' ),
        login_error => $login_error,
        redir_to => $session->get('redir_to'),
        handheld => $handheld_login
    );
    if( $self->no_login_page ){
        $env->{'Plack::Middleware::Auth::Form.LoginForm'} = $form;
        return $self->app->( $env );
    }
    else {
        my $content;

        if ($handheld_login) {
            $content = $self->_wrap_body_handheld( $form );
        }
        else {
            $content = $self->_wrap_body(
                sprintf(
                    "$form\n<div class='formrow'>After login: %s</class>",
                    $session->get('redir_to')
                )
            );
        }

        return [
            HTTP_OK,
            [ 'Content-Type' => 'text/html', ],
            [ $content ]
        ];
    }
}

sub _render_form {
    my ( $self, %params ) = @_;
    my $out = '';
    if( $params{login_error} ){
        $out .= qq{<div class="error_msg">$params{login_error}</div>};
    }
    my $username = defined $params{username} ? $params{username} : '';

    my $message = '';
    if ( $self->plack_session->get('disabled_account') ) {
        $self->plack_session->remove('disabled_account');
        $message = '<p>Your XTracker account is disabled. Please contact Service Desk</p>';
    }

    my $action = $params{handheld} ? "/HandHeld" : "/Login";

    $out .= <<END;
    $message
    <form name="loginForm" action="$action" method="post" class="narrowlabels">
        <div class="formrow">
            <label for="username">Username</label>
            <input type="text" id="username" name="username">
        </div>
        <div class="formrow">
            <label for="password">Password</label>
            <input type="password" id="password" name="password">
        </div>
        <div class="formrow buttons">
            <input type="hidden" name="get" value="">
            <input type="hidden" name="uri" value="">
            <input type="submit" name="submit" class="button" value="Login &raquo;">
        </div>
    </form>

    <script type="text/javascript">
        document.loginForm.username.focus();
    </script>
END
    return $out;
}

sub _logout {
    my($self, $env) = @_;

    my $logger = xt_logger('UserLogin');
    my $source_ip = $env->{HTTP_X_FORWARDED_FOR} || "0.0.0.0";
    my $ajax_log_prefix = ( $self->looks_like_ajax ? 'AJAX ' : '' );

    my $session = $self->plack_session;
    my $user_id = $session->get('user_id') || '';

    $self->_expire_session($session);

    $logger->info($ajax_log_prefix .
                  "LOGOUT: USER=$user_id "
                  . 'SESSION=' . $session->id . ' '
                  . 'SOURCE_IP=' . $source_ip . ' '
                  . 'DELETED');

    # support a logout that requests 'HandHeld'
    my $params = Plack::Request->new( $env )->parameters;
    my $location;
    if ($self->_is_handheld($env)){
        $location = '/HandHeld';
    } else {
        $location = $self->after_logout || '/Home';
    }

    return [
        303,
        [ Location => $location ],
        [ $self->_wrap_body( "<a href=\"/\">Home</a>") ]
    ];
}

# This is a specialised version of the session expire method to remove
# all data from the session except the disabled_account setting.

sub _expire_session {
    my ( $self, $session) = @_;
    die unless ref $session eq 'Plack::Session';

    for my $key ($session->keys) {
        next if $key eq 'disabled_account';
        $session->remove($key);
    }
}


sub _wrap_body_handheld {
    my ($self, $content) = @_;

    my $dc = config_var('DistributionCentre', 'name');

    return <<"ENDHTML"

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
   "http://www.w3.org/TR/html4/strict.dtd">
<html lang="en">
    <head>
        <title>XTracker</title>
        <style type="text/css" media="screen">\@import "/css/xtracker.css";</style>
        <style type="text/css" media="screen">\@import "/css/xtracker_static.css";</style>
        <script language="javascript" src="/javascript/form_validator.js"></script>
        <script language="javascript" src="/javascript/validate.js"></script>
    </head>
    <body class="handheld">
        <div id="container">
            <div id="header">
                <img src="/images/logo_handheld.gif" width="75" height="24" alt="xTracker Home"><span>DISTRIBUTION</span><span class="dc">$dc</span>
            </div>

            <div id="content">
                <div id="channelTitle" style="display: none;">
                     <span>Sales Channel</span> / <span class="title-"></span>
                </div>
                $content
<script type="text/javascript">
    document.loginForm.username.focus();
</script>
                </div>
            </div>
        </div>
    </body>
</html>
ENDHTML
}


# this is experimental and horrifically hacky!
sub _wrap_body {
    my($self, $content) = @_;

    my $instance    = uc( config_var('XTracker','instance') );

    return <<"ENDHTML"
<html lang='en'>
    <head>
        <title>Login</title>
        <link rel="stylesheet" type="text/css" href="/yui/grids/grids-min.css">
        <link rel="stylesheet" type="text/css" href="/yui/button/assets/skins/sam/button.css">
        <link rel="stylesheet" type="text/css" href="/yui/datatable/assets/skins/sam/datatable.css">
        <link rel="stylesheet" type="text/css" href="/yui/tabview/assets/skins/sam/tabview.css">
        <link rel="stylesheet" type="text/css" href="/yui/menu/assets/skins/sam/menu.css">
        <link rel="stylesheet" type="text/css" href="/yui/container/assets/skins/sam/container.css">
        <link rel="stylesheet" type="text/css" href="/yui/autocomplete/assets/skins/sam/autocomplete.css">
        <link rel="stylesheet" type="text/css" href="/yui/calendar/assets/skins/sam/calendar.css">

        <link rel="stylesheet" type="text/css" media="screen" href="/css/xtracker.css">
        <link rel="stylesheet" type="text/css" media="screen" href="/css/xtracker_static.css">
    </head>
    <body class="yui-skin-sam">
        <div id="container">
        <div id="header">
            <div id="headerTop">
                <div id="headerLogo"><img src="/images/logo_small.gif" alt="xTracker"></div>
                <select onChange="location.href=this.options[this.selectedIndex].value">
                    <option value="">Go to...</option>
                    <optgroup label="Management">
                        <option value="http://fulcrum.net-a-porter.com/">Fulcrum</option>
                    </optgroup>
                    <optgroup label="Distribution">
                        <option value="http://xtracker.net-a-porter.com">DC1</option>
                        <option value="http://xt-us.net-a-porter.com">DC2</option>
                        <option value="http://xt-hk.net-a-porter.com">DC3</option>
                    </optgroup>
                    <optgroup label="Other">
                        <option value="http://xt-jchoo.net-a-porter.com">Jimmy Choo</option>
                    </optgroup>
                </select>
            </div>
            <div id="headerBottom">
                <img src="/images/model_${instance}.jpg" width="157" height="87" alt="">
            </div>
            <div id="nav1" class="yuimenubar yuimenubarnav"></div>
        </div>

        <div id="content">
            <div id="contentLeftCol"></div>

            <div id="contentRight"class="noleftcol">
                <div id="pageTitle"> <h1>Login</h1> </div>

                $content

                <script type="text/javascript">
                    document.loginForm.username.focus();
                </script>
            </div>
        </div>
        <p id="footer">NAP Login Screen</p>
    </div>
</body>
</html>
ENDHTML
}


1;



=pod

=head1 NAME

Plack::Middleware::Auth::Form- Form Based Authentication for Plack

=head1 BASED HEAVILY ON

L<Plack::Middleware::Auth::Form>

=cut
