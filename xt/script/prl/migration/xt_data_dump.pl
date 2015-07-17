#!/opt/xt/xt-perl/bin/perl

use strict;
use warnings;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );

=head1 NAME

script/prl/migration/xt_data_dump.pl

=head1 DESCRIPTION

Dumps data related to Locations, Products and quantity information.
Which is then used for importing into PRL application.

Results are CSV files.

=head1 SYNOPSIS

In terminal run following command:

    script/prl/migration/xt_data_dump.pl \
        [ --dump-directory=/path/to/directory/with/results ]
        [ --filename-locations=filename_with_locations ]
        [ --filename-products=filename_with_products ]
        [ --filename-quantities=filename_with_quantities ]
        [ --only-locations ]
        [ --only-products ]
        [ --only-quantities ]

All parameters in "[ ... ]" are optional, if they are not provided default
values are used. Please read script's output to see where results were placed.

=cut

use Getopt::Long;
use Pod::Usage;

use XTracker::Script::PRL::DumpData;

# just to make sure user is constantly updated
local $| = 1;

my %opt;

my $result = GetOptions( \%opt,
    'help|h|?',
    'silent',
    'dump-directory=s',
    'filename-locations=s',
    'filename-products=s',
    'filename-quantities=s',
    'only-locations',
    'only-products',
    'only-quantities',
);

pod2usage(1) if (!$result || $opt{help});


my $dumper = XTracker::Script::PRL::DumpData->new;

# use default dump directory if it was not provided
$dumper->dump_directory($opt{'dump-directory'} || '/tmp/prl_migration');

$dumper->filename_location($opt{'filename-locations'})    if $opt{'filename-locations'};
$dumper->filename_products($opt{'filename-products'})     if $opt{'filename-products'};
$dumper->filename_quantities($opt{'filename-quantities'}) if $opt{'filename-quantities'};

$dumper->verbose(0) if $opt{'silent'};

if ($opt{'only-locations'}) {
    $dumper->dump_locations;
} elsif ($opt{'only-products'}) {
    $dumper->dump_products;
} elsif ($opt{'only-quantities'}) {
    $dumper->dump_quantities;
} else {
    $dumper->invoke;
}


