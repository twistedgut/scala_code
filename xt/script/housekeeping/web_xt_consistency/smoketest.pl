#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;

use Test::Harness::Straps;


open my $lfh, '>', '../logs/smoketest.log' || die "can't open log file: $!";

my $strap = Test::Harness::Straps->new();

my @files = glob('*.t');

my @failures = ();

foreach my $file ( @files ){

    my %results = $strap->analyze_file( $file );

    next if $results{passed};

    my $fail = $results{max} -  $results{ok};

    push @failures, {
                     file => $file,
                     ok   => $results{ok},
                     max  => $results{max},
                     fail => $fail,
                 };
}

for my $failure ( @failures ){

    my $message = sprintf( "%s:\n\tExpected: %d\n\tPassed: %d Failed: %d\n", @$failure{qw( file max ok fail )} );
    print $lfh $message;
}

close $lfh;
