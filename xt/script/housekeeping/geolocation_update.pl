#!/opt/xt/xt-perl/bin/perl

use NAP::policy "tt";
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
our $VERSION = '0.01';
use LWP::Simple qw/ mirror RC_NOT_MODIFIED RC_OK $ua /;
use File::Copy  qw/ mv /;
use File::Path qw /make_path /;
use File::Spec;
use XTracker::Config::Local     qw( config_var );

# CANDO-2013
# This script is used to download Database(s) from Maxmind to use for getting
# Geolocation related information.
# As of now we are dowloading database:
# *  GeoLiteCity.dat

# Here is a sample cron entry that check daily for new files.
# 34 15 * * * /usr/local/bin/geolocation_update.pl

# This script requires download/destination directories to exists on server
-d ( my $download_dir = config_var('SystemPaths','geoloc_db_download_path') ) or die "Directory Does not exists: $!";
-d ( my $dest_dir     = config_var('SystemPaths','geoloc_db_file_path') )  or die "Directory does not exists: $!";



my %mirror = (
    # local-filename       geolite-name
    config_var('GeoLocation','db_filename') => config_var('GeoLocation', 'remote_filename'),
);

$ua->agent("MaxMind-geolite-mirror-simple/$VERSION");
my $dl_path = config_var('GeoLocation','remote_urlpath');

chdir $download_dir or die $!;

#download *.dat.gz file and unzip it.
for my $f ( keys %mirror ) {

    my $local_file = $mirror{$f}."\.gz";
    $f .= ".gz";
    my $rc = mirror( $dl_path . $local_file, $f );
    # if file has not modified do not download.
    next if $rc == RC_NOT_MODIFIED;

    #if file is updated or is new
    if ( $rc == RC_OK ) {
        system ("gunzip $download_dir/$f");
        my $outfile = $f;
        $outfile =~ s/.gz$//;
        #copy the file to destination directory
        mv( $outfile, File::Spec->catfile( $dest_dir, $outfile ) ) or die $!;
    }
}

exit 0;
