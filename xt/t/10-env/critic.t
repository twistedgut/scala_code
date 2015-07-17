#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Find::Rule;
use Perl::Critic;
use Perl::Critic::Violation;
use NAP::policy "tt", ();

BEGIN {
    if ($ENV{'NO_PERL_CRITIC'}) {
        Test::More::plan(skip_all => "Skipping Critic Tests");
    }
}

my $d = $ENV{'XTDC_BASE_DIR'};

# This file searches for Perl files in the distribution, and runs perlcritic
# against them. It has a list of all Perl files at its time of creation, which
# it removes from the list - in this way, we only test new code. You are
# encouraged to remove files from that list as you develop and improve them.
# The eventual goal is to run against the full codebase. If you add new files to
# this, you will be expected to explain yourself.

# Pass the argument '--full' to this script when running if you'd like detailed
# explanations of the problems found.
if ( grep {/--full/} @ARGV ) {
    Perl::Critic::Violation::set_format("%m at line %l. %e. \n%d\n");
}

# Get a list of all Perl files in the distribution
my @files = File::Find::Rule
    ->file()
    ->name( qr/\.(t|pl|pm)$/ )
    ->in( "$d/t", "$d/lib", "$d/script", "$d/t_aggregate" );

# Non-excluded files should pass this
my $critic = Perl::Critic->new(
    -severity => 'stern',
    -profile  => NAP::policy->critic_profile,
);

# Load up the exclusion list
my %exceptions = map { my $line = $_; chomp($line); $line => 1 } (<DATA>);

# Cause a test failure if any of the excluded files are deleted
fail(
    join q{, }, "found exception for '$_' - this file can't be found,",
        'please remove it from the exception list in the __DATA__ section of this test'
) for grep { !-f "${d}/$_" } keys %exceptions;

# Sometimes we want to redo our exclusion list - let's say we've changed a rule
# and want to find all new violators...
if ( grep {/--violators/} @ARGV ) {
    for my $file ( sort @files ) {
        print STDERR "Testing $file\n";
        print "$file\n" if $critic->critique($file);
    }
    exit;
}

# files to ignore which are generated as part of the
# Test App. which are absent when it's not running
my %ignore_if_absent    = map { $_ => 1 } ( qw(
                                    t/conf/apache_test_config.pm
                                    t/conf/modperl_inc.pl
                                    t/conf/modperl_startup.pl
                                ) );

# Let's trim our exclusion list as we move/delete files
for my $file ( sort keys %exceptions ) {
    fail(join q{ },
        "Excluding non-existent file $file from being critiqued.",
        'Remove the exclusion to make this test pass.'
    ) unless -f $file || $ignore_if_absent{ $file };
}

my %files_to_test = map {
    my $file = $_;
    $file =~ s!^$d/!!;
    ( $file => ( ! $exceptions{$file} ) );
} @files;

my @files_to_test = keys %files_to_test;
note(scalar(@files_to_test) . " files to test");

note "
*** NOTE ***
Find broken tests by looking for
  'Perl Critic violations found'
and
  'Expected to find Critic violations'
in the test output
";

for my $file (sort @files_to_test) {
    my @violations = $critic->critique( $file );

    if($files_to_test{$file}) {
        # Should work
        if (@violations) {
            fail("Perl Critic violations found in $file");
            diag( $_->to_string ) for @violations;
        } else {
            pass("Perl Critic violations not found in $file");
        }
    }
    else {
        # Expected to fail
        if (@violations) {
            local $TODO = "Legacy code, expected to fail";
            fail("Perl Critic violations expectedly found in $file");
            diag( $_->to_string ) for @violations;
        } else {
            diag("\n\n");
            fail("Expected to find Critic violations in ($file), but none found.
==> This is excellent news! <==
To fix this test, please remove the file ($file)
from the __DATA__ section in
" . __FILE__ . "\n");
        }
    }
}



done_testing;
__DATA__
