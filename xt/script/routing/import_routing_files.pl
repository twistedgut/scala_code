#!/opt/xt/xt-perl/bin/perl
#
# Process files that have been dumped into the '/var/data/xt_static/routing/schedule'
# directory and create 'routing_schedule' DB records for them.
#
#
# this script is designed to be invoked from 'script/process_routing_files.pl'
#


use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use DateTime;
use File::Copy;
use File::Spec::Functions   qw( catdir );
use File::Path              qw( mkpath );
use XML::Simple;
use Data::Dump              qw( pp );

BEGIN { $ENV{XT_LOGCONF} = 'process_routing.conf'; }

use XTracker::Logfile               qw( xt_logger );
use XTracker::Config::Local         qw( config_var );
use XTracker::Database              qw( get_database_handle );

use XT::Routing::Schedule;

my $now     = DateTime->now( time_zone => "local" );
my $logger  = _setup_logger( $now );

# set-up the path's used by the script
my $date_dir    = $now->ymd('');
my $base_path   = config_var( 'SystemPaths', 'routing_dir' );
my $in_path     = catdir( $base_path, 'schedule/ready' );
my $arch_path   = catdir( $base_path, 'schedule/processed', $date_dir );
my $fail_path   = catdir( $base_path, 'schedule/failed', $date_dir );

# get all the files that are waiting to be processed
opendir( IN_DIR, $in_path ) or _cant_open_dir( $logger, $in_path );
# sort files oldest to newest
my @in_list = grep { m/^\w+.*\.xml$/ } readdir( IN_DIR );
closedir( IN_DIR );

if ( !@in_list ) {
    $logger->info( "No files found to process in: '$in_path'" );
    exit(0);
}

# sort the files in ASCENDING Last Mod Date Order (mtime)
my %file_stat   = map { $_ => ( stat( "$in_path/$_" ) )[9] } @in_list;
my @file_list   = sort { $file_stat{ $a } <=> $file_stat{ $b } } keys %file_stat;

# get a new 'XT::Routing::Schedule' object
my $schedule    = XT::Routing::Schedule->new();

# to store parsed file contents
my @files_parsed;

# parse the files
foreach my $file ( @file_list ) {
    $logger->info( "Filename: ".$file );

    my $schedule_xml;
    eval {
        # load the XML File
        $schedule_xml   = XMLin( "$in_path/$file" );
        if ( !defined $schedule_xml ) {
            die "Couldn't get an XML::Simple Object";
        }

        my $content = $schedule->parse_file_content( $schedule_xml );
        die "File was not Parsed"               if ( !defined $content );
        push @files_parsed, { filename => $file, content => $content };
    };
    if ( my $err = $@ ) {
        $logger->error( "Parsing File: $file, XMLin Contents: ".pp( $schedule_xml )."\n$err" );
        _move_file( $logger, $file, $in_path, $fail_path );
    }
}

if ( !@files_parsed ) {
    $logger->error( "There were ".scalar( @file_list )." files found but NONE were able to be parsed" );
    exit(1);
}

# get a schema and assign it to the $schedule object
my $schema  = _get_schema( $logger );
$schedule->schema( $schema );

# now with the parsed file contents
# create db records from them
foreach my $file_parsed ( @files_parsed ) {

    my $file    = $file_parsed->{filename};
    my $content = $file_parsed->{content};

    eval {
        $schema->txn_do( sub {
            $schedule->process_content( $content, $logger );
            _move_file( $logger, $file, $in_path, $arch_path );
        } );
    };
    if ( my $err = $@ ) {
        $logger->error( "Processing File: $file, Parsed File Contents: ".pp( $content )."\n$err" );
        _move_file( $logger, $file, $in_path, $fail_path );
    }
}

# now send out the Alerts to the Customers
$logger->info( "Sending Out Alerts" );
if ( my $potential_alerts = $schedule->number_of_alerts ) {
    my $alert_count = 0;
    $logger->info( "Potential Alerts to Send: " . $potential_alerts );
    eval {
        $alert_count    = $schedule->send_alerts( $logger );
    };
    if ( my $err = $@ ) {
        $logger->error( "Sending Alerts: $err" );
    }
    $logger->info( "Actual Calls to Send Alerts: $alert_count" );
}
else {
    $logger->info( "No Alerts to Send" );
}

exit(0);

#----------------------------------------------------------------------

sub _get_schema {
    my $logger      = shift;

    $logger->info( 'Acquiring XT DB handle' );

    return get_database_handle(
                    {
                        name    => 'xtracker_schema',
                    }
                );
}

sub _cant_open_dir {
    my $logger  = shift;
    my $path    = shift;

    my $msg = "Can't open Directory: '$path'";
    $logger->fatal( $msg ) && die $msg;
}

sub _setup_logger {
    my $now     = shift;

    my $logger  = xt_logger( '' );

    $logger->info( "START: PROCESS SCHEDULE FILES: ".$now );

    return $logger;
}

sub _move_file {
    my ( $logger, $file, $from, $to )    = @_;

    $logger->info( "Moving File: $file, from: $from, to: $to" );

    unless ( -d $to ) {
        mkpath( $to, 0, oct( '0775' ) );
    }

    move( "$from/$file", "$to/$file" ) or die( "Couldn't move File: $file, $!" );

    return;
}
