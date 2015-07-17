#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

# I create a URL Coverage database from Hudson.

use lib 't/lib/';
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
#use List::MoreUtils qw(uniq);
use File::Temp qw( tempfile );
use Getopt::Long::Descriptive;
use Test::XT::URLCoverage::File;
use Test::XT::URLCoverage::Database;

my ($opt, $usage) = describe_options(
    'generate_url_coverage_db.pl %o',
    [ 'output|o=s', "Output database - defaults to 'url_coverage.data'", { default => 'url_coverage.data' } ],
);

my $db = Test::XT::URLCoverage::Database->new();

# Iterate over all the options...
my $branch   = 'master';
my @sections = qw( other orders other ); # disabled env_units because it doesn't contain web requests
my @dcs      = qw( dc1 dc2 );

for my $dc ( @dcs ) {
    for my $section ( @sections ) {

        #
        # Grab the datafile
        #
        my $section_atom = "xtracker_${branch}_${section}_${dc}";
        my ($section_fh, $section_filename) = tempfile( EXLOCK => 0, UNLINK => 0 );

        print "Job: $section_atom - Downloading to: $section_filename\n";
        print (('-' x 72)."\n");

        my $url = 'http://build01.wtf.nap:8181/job/' . $section_atom .
        # This is the URL of the last succesful build
            '/lastSuccessfulBuild/artifact/t/tmp/url_coverage.data';
        # This is some bullshit. Don't use it unless you know why.
        #    '/ws/t/tmp/url_coverage.data';

        print "$url\n";
        `curl -o $section_filename $url`; ## no critic(ProhibitBacktickOperators)
        print (('-' x 72)."\n");

        my $size = (stat( $section_filename ))[7];
        if ( $size < 300 ) {
            print "$section_filename is $size bytes; ABORT...\n";
            die "Data files possibly corrupt";
        } else {
            print "$section_filename is $size bytes; parsing...\n";

            # Write the contained records to the DB in memory
            my $file = Test::XT::URLCoverage::File->new({
                filename => $section_filename });
            my @records = $file->fetch_all;
            for ( @records ) {
                $db->record( $_ );
            }
        }

        print "\n\n\n";
    }
}

# Write the in-memory DB to disk
my $output = $opt->{'output'};
$db->write_file( $output );

system('ls','-lh',$output);
