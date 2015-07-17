#!/opt/xt/xt-perl/bin/perl

=head1 NAME

xt.psgi - start the XTracker web application

=head1 DESCRIPTION

=head2 PLACK_ENV

Explanation of the PLACK_ENV environment variable:

    1. development --> local development on a VM, log and static directories
        under a local checkout, plus the dev panel.
        But see WHM-2941 for a bug.

    2. unittest --> same as 1, but without the dev panel.
        Used by Jenkins to avoid WHM-2941 bug.

    3. test --> bypasses LDAP login, production log and static directory layout.
        Used in DAVE when they are running automated regression.

    4. deployment --> production/live. Normal login and directory layout

=head1 TODO

Refactor this script, it's become confusing as the different environments have
naturally evolved into a bit of a mess.

=cut

use NAP::policy "tt";
use Plack::Builder;
use Plack::Session::State::Cookie;
use Storable ();

BEGIN {
    if (not defined $ENV{XTDC_BASE_DIR}) {
        warn "XTDC_BASE_DIR is undefined - did you forget to source the .env file?\n";
        exit;
    }

    $ENV{XT_LOGCONF} = 'xtracker.conf';
}
use lib $ENV{XTDC_BASE_DIR} . qw(/lib);
use lib $ENV{XTDC_BASE_DIR} . qw(/lib_dynamic);
use Plack::App::File;
use Plack::App::FakeModPerl1;
use Plack::App::XT::Progressive;
use HTTP::Status qw(:constants);
use XT::Plack::CSRF;
use XT::Startup;
use Log::Dispatch;
use Log::Dispatch::File::Stamped;
use XTracker::Config::Local qw( config_var config_section );
use Plack::Middleware::Log4perl;
use XTracker::Database ':common';
use XTracker::Logfile;
use XTracker::Printers::Populator;
use Module::Runtime 'use_module';

builder {
    # conditionally load features based on PLACK_ENV
    #   PLDEBUG=1 /opt/xt/xt-perl/bin/plackup xt.psgi -r -E development
    my %is_in = (
        'development'   => $ENV{PLACK_ENV} ~~ 'development',
        'unittest'      => $ENV{PLACK_ENV} ~~ 'unittest',
        'test'          => $ENV{PLACK_ENV} ~~ 'test',
        'deployment'    => $ENV{PLACK_ENV} ~~ 'deployment',
    );
    my $is_side_panel_enabled = config_var('TestTools', 'enable_side_panel');

    enable "Log4perl", category => 'Plack';

    enable 'LogBeforeProcessing'
        if config_var('Logging', 'log_before_processing') // 1;

    # In DAVE and production environments we run behind an nginx reverse
    # proxy. This middleware enables proxy headers to override some
    # environment variables which is particluarly important for Catalyst
    # $c->uri_for etc. If a proxy is not in place (i.e. in development) this
    # should have no effect as proxy headers will be absent
    enable 'Plack::Middleware::ReverseProxy';

    # haven't yet found a way to automate the rewrites from xt_location.conf
    enable 'Rewrite',
        rules => sub {
            # / -> /Home
            s{^/$}{/Home};

            # Product Aprroval archive shortcut
            s{^/StockControl/ProductApproval/Archive$}{/StockControl/ProductApproval?action=archive};

            # MaintenanceMode
            # RewriteRule !^/MaintenanceMode.*$  /MaintenanceMode [PT,L]
            if ( -f '/tmp/maintenance.on' ) {
                $_ = '/MaintenanceMode'
                    unless m{^/MaintenanceMode.*$};
            }

            # check if any legacy URLs need re-writting while
            # the XT Access Controls Project is still in progress
            if ( my $rewrite = _rewrite_acl_legacy_url( $_, $_[0] ) ) {
                $_ = $rewrite->{redirect_to};
                return $rewrite->{status_code};
            }

            return;
        }
    ;

    # compress response if browser supports
    enable 'Deflater';

    # Get the application version from local file
    my $version;
    if ( open my $version_fs, "<", "VERSION" ) {
        read $version_fs, $version, 100;
        close $version_fs;
    }

    enable 'NAP::ServerStatus', (
        path                => '/status',
        authorised_hosts    => '10.5/16',
        version             =>  $version || 'UNKNOWN',
        output_format       => 'json',
    );

    # Serve up static content

    my @static_content_folders = qw{images css jquery jquery-ui yui javascript favicon.ico};
    my @test_static_content_folders = (qw/test/);
    @static_content_folders = (@static_content_folders, @test_static_content_folders)
        if ($is_in{test} or $is_in{development} or $is_in{unittest});

    foreach my $place (@static_content_folders) {
        enable_if { -e $ENV{XTDC_BASE_DIR} . "/root/static/$place" }
            "Static", path => qr{^/${place}},
                      root => "$ENV{XTDC_BASE_DIR}/root/static/";
    }

    # Serve up dynamic content
    foreach my $place (qw{barcodes data export images include
                          manifest/pdf print_docs reports routing utilities}) {
        my $root = '/var/data/xt_static';

        if(($is_in{development} or $is_in{unittest})){
            $root = $ENV{XTDC_BASE_DIR} . '/tmp' . $root
        }

        enable_if { (-e "$root/$place") } "Static", path => qr{^/${place}},
                                                    root => $root;
    }

    # Make sure we start this request with a new database connections to
    # xtracker - as these now persist throughout the life of the process, we
    # want to minimise the risk of starting with a connection polluted with,
    # say any previous requests' SET $runtime_parameter, or open transactions.
    # Having the connections persist for the whole process is not a bad thing
    # per se, but we probably want to be more sure our change won't break
    # anything.
    enable 'NAP::ClearSingletonDBH';

    # needs to be as near the 'top of the stack' as possible
    enable_if { $is_side_panel_enabled }
        'Debug';
    enable_if { $is_side_panel_enabled }
        'Debug::NAPEnv';
    enable_if { $is_side_panel_enabled }
        'Debug::DBITrace';
    enable_if { 0 and $is_side_panel_enabled }
        'Debug::ModuleVersions';
    enable_if { $is_side_panel_enabled }
        'Debug::TestTools';

    # hijack the nginx errordocs if we appear to have them
    my $nginx_html = '/usr/share/nginx/html';
    enable_if { -d $nginx_html }
        "Plack::Middleware::ErrorDocument",
            404 => $nginx_html . '/xt-404.html',
            413 => $nginx_html . '/xt-413.html',
            500 => $nginx_html . '/xt-500.html',
            502 => $nginx_html . '/xt-502.html',
            504 => $nginx_html . '/xt-504.html',
        ;

    # we must enable this *before* the Auth plugin!
    my $session_store = config_var('Session', 'store') // 'DBI';
    my %session_store_args = (
        DBI => [ get_dbh => sub { xtracker_schema->storage->dbh } ],
    );
    enable 'Session',
      store => use_module("Plack::Session::Store::$session_store")->new(
          @{ $session_store_args{$session_store} // [] }
      ),
      state => Plack::Session::State::Cookie->new(expires => 5400)
    ;

    # prevent some obvious evil
    # enable_if
    #   { my $content_type = $_[0]->{CONTENT_TYPE} // '';
    #     my $xmlhr = $_[0]->{HTTP_X_REQUESTED_WITH} // '';
    #     !( $is_in{test} )
    #       # Skip CSRF checks if this is an API request. We're guessing this
    #       # based on the request reporting it's content type as JSON and the
    #       # JSON request not including a header indicating AJAX. This is
    #       # similar to Plack::Middleware::NAP::Authenticate->looks_like_ajax
    #       # which we may want to use in the future.
    #       && ($content_type ne 'application/json' || $xmlhr eq 'xmlhttprequest' )
    #   }
    #   'CSRFBlock',
    #       parameter_name  => 'csrf_secret',
    #       token_length    => 20,
    #       session_key     => 'csrf_token',
    #       onetime         => 0,
    #       meta_tag        => 'csrf_token',
    #       blocked         => sub {
    #           return XT::Plack::CSRF::handle_csrf(@_);
    #       },
    # ;

    # set correct content type for ajax requests, etc
    enable 'SetContentType';

    # this is pretty much a hack to stop:
    # Use of uninitialized value $ct in pattern match (m//) at /opt/xt/xt-perl/lib/site_perl/5.14.2/Plack/Middleware/CSRFBlock.pm line 125.
    enable 'DefaultContentType';

    # TODO: make the test authentication more sensible
    #   for the moment we're taking any crap and making everything
    #   successfully log in as 'it.god'
    #   - but only if we're in test mode '-E test' - see t/TEST.PSGI
    use XT::Plack::Authenticate::Automated;
    enable_if { ($is_in{test} or $is_in{development} or $is_in{unittest}) }
        "NAP::Authenticate",
            authenticator => XT::Plack::Authenticate::Automated->new()
        ;

    enable_if { ! ( $is_in{test} or $is_in{development} or $is_in{unittest} ) }
        "NAP::Authenticate";

    # Request log with response timings
    my $access_logfile
      = config_var('SystemPaths', 'xtdc_logs_dir') . '/xtracker_access.log';
    my $logger
      = Log::Dispatch::File::Stamped->new( name => 'logfile',
                                           min_level => 'info',
                                           filename => $access_logfile,
                                           mode => 'append',
                                           permissions => 0664,
                                           autoflush => 1,
                                           syswrite => 1,
                                           binmode => ':utf8',
                                         );

    enable "Plack::Middleware::AccessLog::Timed",
        format => "%v %P %h %l %u %t \"%r\" %>s %b %D",
        logger => sub { $logger->log(level => 'info', message => @_) };

    my $app = Plack::App::XT::Progressive->new->to_app;

    if ( $is_in{test} || $is_in{development} || $is_in{unittest} ) {
        # Not using 'lib' so we only add t/lib to inc if we're in this block
        unshift @INC, $ENV{XTDC_BASE_DIR} . '/t/lib';
        require Test::XT::Override;
        Test::XT::Override->apply_roles;
        # ALWAYS populate from config when we start our test server
        # TODO: A *very ugly* hack, as we are apparently in 'test' mode in our
        # DAVE envs - so this code would get executed and attempt to read the
        # CUPS printers.conf file which is only readable by root. We need to
        # reorganise our psgi file and clean up all the hacks in here :/
        XTracker::Printers::Populator->new->populate_db unless $is_in{test};
    }

    # Due to DHL not handling anything other than ASCII we encode the manifest
    # in Latin-1 - which means we also need to get our server to match
    mount "/manifest/txt" => Plack::App::File->new(
        root => $ENV{XTDC_BASE_DIR} . '/root/static/manifest/txt',
        encoding => 'iso-8859-1',
    );
    mount "/" => $app;
};

# this is used to Rewrite any URLs that have been
# converted into Authorative URLs for the XT Access
# Controls Project but still might need to be active
# for legacy reasons so this method will convert them
# into their Authorative version. This isn't very
# spohisticated it doesn't mess with the Query String
# it simply supplies a URL Path that will be used in
# a Redirect.
#
# TODO: Remove when XT Access Controls Project has been completed
sub _rewrite_acl_legacy_url {
    my ( $url, $psgi_env ) = @_;

    my $rewrites = config_section('ACL_Rewrite_Legacy_URL') // {};

    REWRITE:
    foreach my $rewrite ( @{ $rewrites->{rewrite} } ) {
        next REWRITE    if ( !$rewrite->{url_regex} );

        my $url_regex = $rewrite->{url_regex};
        my $qry_regex = $rewrite->{qry_str_regex} // '.*';
        my $query_str = $psgi_env->{QUERY_STRING} // '';

        if (       $url =~ m/${url_regex}/
          && $query_str =~ m/${qry_regex}/ ) {
            my $status_code = $rewrite->{status_code};
            return {
                redirect_to => $rewrite->{redirect_url},
                status_code => eval "HTTP::Status::${status_code};",
            };
        }
    }

    return;
}
