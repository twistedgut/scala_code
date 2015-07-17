#!/opt/xt/xt-perl/bin/perl
#
# get some initialization parameters for a shell script from NAP
# properties and the XT config, then stuff that into the environment
# of a shell script, then exec the script with whatever arguments we
# were passed

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

# The XT_LOGCONF env var must be set before XTracker::Logfile is imported via
# the XTracker:: 'use' chain otherwise it will pick up 'default.conf'
BEGIN {
    if( ! defined $ENV{XT_LOGCONF} ){
        $ENV{XT_LOGCONF} = 'order_importer.conf';
    }
}

use XTracker::Config::Local qw( config_section_slurp );
use XTracker::Logfile qw( xt_logger );

use Data::Dump      qw( pp );       # used to Dump the ENV for debugging

use Fcntl ':flock';

my $command=$0;

$command=~s/\.pl\z/.sh/;

die "Unable to find matching shell script '$command'\n" unless -x $command;

my $self_fd;

my $logger = xt_logger( qw( OrderImporter ) );

my $use_exec = 1;

# NOTE: this locking mechanism will *only* work when XT is
# installed on a local file system
#
# Install it on a network drive, and anything might happen

if ( $command =~ m{singleton} ) {
    unless (    open ( $self_fd, '<', $command )
             && flock ($self_fd, LOCK_EX | LOCK_NB) ) {
        $logger->info( "Singleton script '$command' already locked by another process -- QUITTING" );

        exit 0;
    }

    $use_exec = 0;
}

my $system_paths                = config_section_slurp('SystemPaths');
my $names                       = config_section_slurp('ParallelOrderImporterNames');
my $priority_by_shipping_method = config_section_slurp('ParallelOrderImporterShippingPriorities');
my $priority_by_business        = config_section_slurp('ParallelOrderImporterBusinessPriorities');
my $tunable_parameters          = config_section_slurp('ParallelOrderImporterTunableParameters');

# override these from *our* environment, if they're there
foreach my $key (keys %$tunable_parameters) {
    my $var_name = uc $key;

    unless (exists $ENV{$var_name} && defined $ENV{$var_name}) {
        $ENV{$var_name} = $tunable_parameters->{$key};
    }
}

foreach my $key (keys %$system_paths) {
    $ENV{uc($key)} = $system_paths->{$key};
}

foreach my $key (keys %$names) {
    $ENV{uc($key).q{_NAME}} = $names->{$key};
}

foreach my $key (keys %$priority_by_shipping_method) {
    $ENV{uc($key).q{_SHIPPING_PRIORITY}} = $priority_by_shipping_method->{$key};
}

foreach my $key (keys %$priority_by_business) {
    $ENV{uc($key).q{_BUSINESS_PRIORITY}} = $priority_by_business->{$key};
}

$logger->debug( "About to invoke '$command ".join(' ',@ARGV)."', using the '" . ( $use_exec ? 'exec' : 'system' ) . "' command" );
$logger->debug( "${command} ENV: " . pp( \%ENV ) );

exec($command,@ARGV) if $use_exec;

my $retval = 0;

eval {
    $retval = system( $command, @ARGV );
};

my $e = $@;

close $self_fd;

$logger->logdie( "Trouble running '$command': $e\n" )
    if $e;

exit $retval;
