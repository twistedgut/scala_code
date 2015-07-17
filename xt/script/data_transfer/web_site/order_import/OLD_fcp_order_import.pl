#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

use XT::OrderImporter;
use XTracker::Config::Local qw( config_var );
use XML::LibXML;

use XTracker::Database qw( get_database_handle );
use XTracker::Database::Channel qw( get_channels );

use Fcntl ':flock';
use Readonly;

# check if import script already running
open my $SELF, "<", $0 or die print 'Import already running';
flock $SELF, LOCK_EX | LOCK_NB  or exit;

# connect to XT database
my $dbh = get_database_handle( { name => 'xtracker', type => 'transaction' } )
    || die print "Error: Unable to connect to DB";

# Get the DC
Readonly my $DC => config_var('DistributionCentre', 'name');
die q{Could not determine the DC} unless $DC;

# set up web db connections
# for each channel
my $dbh_web;
my $channels = get_channels($dbh);
foreach my $channel_id ( keys %{$channels}) {
    # WARNING this definitely won't process JimmyChoo orders
    # and it hasn't been tested on NAP/Out/MrP orders since refactoring
    if ($channels->{$channel_id}{config_section} eq 'JC') {
        delete $channels->{$channel_id};
        next;
    }
    $dbh_web->{$channel_id} = get_database_handle({
        name => 'Web_Live_' . $channels->{$channel_id}{config_section},
        type => 'transaction',
    }) || die print "Error: Unable to connect to website DB for channel: $channels->{$channel_id}{name}";
}

# xml parser
my $parser = XML::LibXML->new();
$parser->validation(0);

# working directories
my $waitdir  = config_var('SystemPaths', 'xmlwaiting_dir');
my $procdir  = config_var('SystemPaths', 'xmlproc_dir');
my $errordir = config_var('SystemPaths', 'xmlproblem_dir');

# read in waiting directory
opendir(WAITING, $waitdir) or die $!;

while ( defined( my $file = readdir( WAITING ) ) ) {

    next if $file =~ /^\.\.?$/;     # skip . and ..
    next if $file =~ m{^\..*swp};   # skip .*swp files
    next if ( -z "$waitdir/$file" );        # skip if the order file is empty


    print "[ Processing ] $file\n";

    my $path = "$waitdir/$file";

    my $import_error = XT::OrderImporter::process_order_xml(
      path     => $path,
      dbh      => $dbh,
      DC       => $DC,
      dbh_web  => $dbh_web,
      parser   => $parser,
      channels => $channels,
    );


    if ($import_error) {
        XT::OrderImporter::archive($file, $errordir, $waitdir);
    }
    else {
        XT::OrderImporter::archive($file, $procdir, $waitdir);
    }

}

closedir(WAITING);

$dbh->disconnect;

foreach my $channel_id ( keys %{$channels}) {
    $dbh_web->{$channel_id}->disconnect();
}


__END__
