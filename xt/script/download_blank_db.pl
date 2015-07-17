#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use lib 't/lib/';
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use List::MoreUtils qw(uniq);
use File::Temp qw( tempfile );
use Getopt::Long::Descriptive;
use Carp qw(croak);

my ($opt, $usage) = describe_options(
    'download_blank_db.pl %o',
    [ 'dc|d=i',          "DC for which you want a database (either this or URL must be set)" ],
    [ 'url|u=s',         "URL to download from (either this or DC must be set)" ],
    [ 'target|t=s',      "Name of output DB (will be wiped)",     { required => 1 } ],
    [ 'target_host|T=s', "Hostname of output DB (will be wiped)", { default  => 'localhost' } ],

    [],
    [ 'help',       "print usage message and exit" ],
);

print($usage->text), exit if $opt->help;
print( "You must set either 'dc' or 'url'\n",
    $usage->text), exit unless ( $opt->{'dc'} || $opt->{'url'} );

my $url = $opt->{'url'};
unless ( $url ) {
    $url = {
        1 => 'http://build01.wtf.nap:8181/view/Admin-DB/job/admin-db-create_master_template_xtracker/lastSuccessfulBuild/artifact/xtracker_master_template.sql',
        2 => 'http://build01.wtf.nap:8181/view/Admin-DB/job/admin-db-create_master_template_xtracker_dc2/lastSuccessfulBuild/artifact/xtracker_dc2_master_template.sql',
        3 => 'http://build01.wtf.nap:8181/view/Admin-DB/job/admin-db-create_master_template_xtdc3/lastSuccessfulBuild/artifact/xtdc3_master_template.sql'
    }->{ $opt->{'dc'} };
}

# First, download...
my ($schema_fh, $schema_filename) = tempfile( EXLOCK => 0 );
print "Downloading schema to $schema_filename\n";
system 'curl','-o',$schema_filename,$url;

# Complain if we end up with a zero-sized file
die "Something went wrong with that, $schema_filename is blank"
    unless [stat($schema_filename)]->[7] > 0;


#
# Second: Wipe then recreate the target db
#
execute(
    sprintf("Wiping the target db: %s@%s",$opt->{'target'},$opt->{'target_host'}),
    psql =>
        '-Upostgres', '-h' . $opt->{'target_host'},
        '-c DROP DATABASE IF EXISTS ' . $opt->{'target'} . '' );
execute(
    sprintf("Recreating the target db: %s@%s",$opt->{'target'},$opt->{'target_host'}),
    psql =>
        '-Upostgres', '-h' . $opt->{'target_host'},
        '-c CREATE DATABASE ' . $opt->{'target'} );

#
# Third: Load in the blank schema
#
execute(
    "Loading up the blank schema",
    psql =>
        '-Upostgres', '-q',
        '-d' . $opt->{'target'},
        '-h' . $opt->{'target_host'},
        '-o' . $schema_filename . q{.log}, 
        '-f' . $schema_filename,
);

print "Done!\n";

# utilitiy subs
sub execute {
    my ($sys_name, @commands) = @_;
    print STDERR $sys_name . "\n";
    print STDERR (join ' ', @commands) . "\n";
    system( @commands ) == 0 or croak "system " . (join ' ', @commands) . " failed: $?";
    print STDERR "Success\n";
}
