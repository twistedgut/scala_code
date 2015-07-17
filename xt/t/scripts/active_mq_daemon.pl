#!/opt/xt/xt-perl/bin/perl

=head1 NAME

active_mq_daemon.pl - start a lightweight ActiveMQ broker for testing XTracker

=head1 USAGE

 ./t/scripts/active_mq_daemon.pl start  # Start me as a daemon
 ./t/scripts/active_mq_daemon.pl stop   # Stop me if I'm already running
 ./t/scripts/active_mq_daemon.pl status # Find out if I'm running

 ./t/scripts/active_mq_daemon.pl -X     # Start me in the foreground

=cut

use NAP::policy "tt";
use FindBin::libs;

BEGIN {
    #$ENV{NO_XT_LOGGER} = 1;

    # Ensure we can access the dynamic lib
    use Path::Class;
    use lib '' . file(__FILE__)->parent->parent->parent
                               ->subdir('lib_dynamic');
}

use Getopt::Long::Descriptive;
use Proc::Daemon;
use Path::Class;

my $pidfile = $ENV{'XTDC_BASE_DIR'} . '/t/tmp/active_mq_daemon.pid';

my ($opt,$usage) = describe_options(
    '%c %c start|stop|status',
    [ 'pid|p=s', "path to the pidfile, defaults to $pidfile",
      { default => $pidfile } ],
    [ 'X', 'run in foreground' ],
    [ 'help|h', 'this help text' ],
    {
        getopt_conf => [qw(
                              no_ignore_case
                              no_getopt_compat
                              no_auto_abbrev
                      )]
    },
);
if ($opt->help) {
    print $usage->text;
    exit 0;
}

unless ($opt->x) {
    my $daemon = Proc::Daemon->new(
        work_dir => dir()->stringify,
        pid_file => $pidfile,
    );
    if ($ARGV[0] eq 'start') {
        $daemon->Init;
    }
    elsif ($ARGV[0] eq 'stop') {
        $daemon->Kill_Daemon;
        exit 0;
    }
    elsif ($ARGV[0] eq 'status') {
        my $status = $daemon->Status;
        if ($status) {
            say "Test consumer running as $status\n";
        }
        else {
            say "Test consumer dead\n";
        }
        exit 0;
    }
    else {
        warn "Unknown verb $ARGV[0]\n";
        exit 1;
    }
}

# Lazy load this if we get past daemonize. It takes time and we don't
# want to to be doing it unless we're starting...
#
# we need to load the configuration *before* the actual application,
# to get the appropriate files loaded
require Test::XTracker::LoadTestConfig;
require XTracker::Config::Local;
require XT::DC::Messaging;
require Plack::Handler::Stomp::NoNetwork;

my $trace_basedir = XTracker::Config::Local::config_var('Model::MessageQueue','args')->{trace_basedir};

my $process_directory =
    dir($trace_basedir)->absolute( $ENV{'XTDC_BASE_DIR'} )->stringify;

my @subscriptions = map {; {
    destination => $_,
} } XT::DC::Messaging->jms_destinations;

# now we can build the handler
my $handler = Plack::Handler::Stomp::NoNetwork->new({
    subscriptions => \@subscriptions,
    trace_basedir => $process_directory,
    logger => XT::DC::Messaging->log,
});

if (XT::DC::Messaging->can('psgi_app')) {
    $handler->run(XT::DC::Messaging->psgi_app);
}
else {
    XT::DC::Messaging->setup_engine('PSGI');
    $handler->run( sub { XT::DC::Messaging->run(@_) } );
}
