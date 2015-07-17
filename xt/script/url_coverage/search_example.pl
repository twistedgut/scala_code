#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;

use lib 't/lib/';
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Getopt::Long::Descriptive;
use Test::XT::URLCoverage::Database;

#use Carp qw(croak);

my ($opt, $usage) = describe_options(
    'search.pl %o',
    [ 'db|d=s',    "Input database - defaults to 'url_coverage.data'", { default => 'url_coverage.data' } ],
    [ 'index|i=s', "Index to search on - required - see Test::XT::URLCoverage::Database for a full list", { required => 1 } ],
    [ 'term|t=s',  "Search-term to look for in the index - required", { required => 1 } ],
);

my $db = Test::XT::URLCoverage::Database->new();
$db->read_file( $opt->{'db'} );

my ( $count, $matches ) = $db->key_search( $opt->{'index'}, $opt->{'term'} );

print "$count matches found:\n";

use Data::Printer;
p $matches;
