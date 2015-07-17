package XT::Startup;

use NAP::policy "tt";
use English '-no_match_vars';

use XTracker::Config::Local qw( config_var xt_db_server ct_db_server
                                ct_db_name xt_db_name config_section_exists );

=head1 NAME

XT::Startup - Application startup routines

=head1 DESCRIPTION

Startup checks and setup tasks to ensure sane, sensible and profitable running
of the XT system.

=cut

BEGIN{
    if (not defined $ENV{XTDC_BASE_DIR}) {
        warn "XTDC_BASE_DIR is undefined - did you forget to source the .env file?\n";
        exit;
    }
    if (-e "$ENV{XTDC_BASE_DIR}/lib/XTracker/Constants/FromDB.pm") {
        warn "You have an old FromDB.pm file under the lib/XTracker/Constants/ path "
             . "- please remove this before application startup \n";
        exit;
    }
}

# Set the effective user and group for file and directory initialisation. The
# user is as per the system and application configuration. The setting of
# $EGID *must* come first as we give up root privileges and therefore won't
# have the ability to change our group after this.
my $system_user = config_var('SystemUser', 'user');
my ($uid, $gid) = (getpwnam($system_user))[2,3];
local $EGID = "$gid $gid";
local $EUID = $uid;

=head1 TASKS

=head2 Configuration checks

Ensure basic and important config values are set. Without these the
application will not run so we don't allow startup to continue.

=cut

if (not config_section_exists('Database_xtracker')) {
    die qq{I can't find some Database config section.\nYou most likely forgot to source your .env file.}
}

if (not config_section_exists('LDAP')) {
    die qq{You need to upgrade xtracker.conf to include ldap authentication settings.}
}

=head2 PDF checks

Ensure we can generate PDFs using both HTMLDoc and Webkit. The HTMLDoc check
can be removed when this method is fully deprecated

=cut

use HTML::HTMLDoc;
use PDF::WebKit;
# ripped out from Catalyst::Plugin::StartupChecks
sub __check_htmldoc_ok {
    my $htmldoc_response;

    eval {
        $htmldoc_response = qx{htmldoc --version}; ## no critic(ProhibitBacktickOperators)
        if (defined $htmldoc_response) {
            chomp $htmldoc_response;
        }
    };

    # If the value of $? is -1, then the command failed to execute
    if (-1 == $?) {
        die qq{failed to execute htmldoc: $!\n};
    }

    # did we get something looking like a version string?
    elsif (defined $htmldoc_response and $htmldoc_response =~ m{\A[\d\.]+\z}) {
        print( qq{[using htmldoc $htmldoc_response]\n} );
    }

    return;
}

sub __check_webkit_ok {
    my $webkit_response;

    eval {
        $webkit_response = qx{wkhtmltopdf --version}; ## no critic(ProhibitBacktickOperators)
        if (defined $webkit_response) {
            chomp $webkit_response;
        }
    };

    if (-1 == $?) {
        die qq{failed to execute wkhtmltopdf: $!\n};
    }

    elsif (defined $webkit_response and
             my ($ver) = $webkit_response =~ /wkhtmltopdf (\d.+)/) {
        print qq{[using wkhtmltopdf $ver]\n};
    }

    return;
}

__check_htmldoc_ok();
__check_webkit_ok();

=head2 Constants generation

Constants based on sequenced database ids are read from the application
database and written to an application module for use within the code

=cut

# 'require' here rather than 'use' to ensure effective user and group
# applies to the module load. As loading initialises log files it must be
# executed as the configured system user
require XTracker::BuildConstants;

my $do_build = config_var('XTracker', 'build_constants');

# make sure we have constants that are appropriate for our active database
if ($do_build and $do_build eq 'yes') {
    my $xtdc_base_dir = config_var('SystemPaths', 'xtdc_base_dir');
    my $from_db_file = $xtdc_base_dir . q{/lib_dynamic/XTracker/Constants/FromDB.pm};

    say '[ Starting: Build Constants::FromDB]';

    my $builder = XTracker::BuildConstants->new;
    $builder->prepare_constants();
    $builder->spit_out_template($from_db_file)
      or die $!;

    say '[Completed: Build Constants::FromDB]';
}
else {
    say "[Not building Constants::FromDB: build_constants not defined in xtracker.conf]";
}

=head2 Render templated CSS

The CSS template is rendered using local values from the main config
file. This is done at application start up and saved as a static file as a
performance optimisation

=cut

use XTracker::CSS;

say "[ Starting: Building CSS from config]";
foreach my $css (qw/xtracker.css print.css/) {
    XTracker::CSS->render_to_file($css);
}
say "[Completed: Building CSS from config]";


=head2 Preload application modules

Application modules are require'd here so the initial user doesn't take on the
module load time

=cut

if (not exists $ENV{QUICKDEV}) {
    require Module::Pluggable::Object;

    my %opts = (require => 1,);
    @opts{qw(package file)} = caller;
    # TODO: Remove evil hardcoded path
    $opts{search_dirs} = [ config_var('SystemPaths', 'xtdc_base_dir') ];
    $opts{search_path} = [qw( DataCash Interface XTracker XT )];
    $opts{except}      = qr/\A
                            XT::(?:
                                Job
                              | Common
                              | DC::Messaging
                            )
                            | XTracker::(?:
                                Script
                            )
                           /x;

    say '[ Starting: Preloading Application Modules]';
    my $mpo = Module::Pluggable::Object->new(%opts);
    $mpo->plugins;
    say '[Completed: Preloading Application Modules]';
}
else {
    say '[ Skipping: Preloading Application Modules - QUICKDEV detected]';
}

=head2 Preload dependency modules

Application modules are 'use'd here so the initial user doesn't take on the
module load time

=cut

use Cache::Memcached::Managed;
use Data::FormValidator;
use Data::FormValidator::Constraints qw(:closures);
use DBI ();
use DBIx::Class;
use Tie::IxHash ();
use Net::Printer ();
use Net::LDAP ();
use HTML::HTMLDoc ();
use Template ();
use Data::Dumper ();
use Carp ();
use Digest::MD5 ();
use Cache::FileCache;
use Log::Log4perl;

=head2 install DBD drivers

=cut

# from: http://www.perl.com/pub/a/2002/12/04/mod_perl.html
DBI->install_driver("Pg");
DBI->install_driver("mysql");

say '[Completed: XT::Startup tasks]';
