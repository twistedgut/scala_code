#!/opt/xt/xt-perl/bin/perl

# rough script to compare the intersection between pids in
# reconciliation reports and skus mentioned in item_moved messages
# taken from the DLQ.dc1/iws queue

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Path::Class;
use Carp qw( croak );
use Text::CSV_XS;
use Data::Dump qw(pp);

my $dir = @ARGV ? dir($ARGV[0]) : dir();
my $dlqdir = dir($ARGV[1]);

# read data
my $skus = {};
foreach my $file ('skus_in_xt_only', 'skus_in_iws_only', 'skus_that_differ') {
    my $in=$dir->file("${file}-filtered.csv")->openr;
    my $csv=Text::CSV_XS->new({
        binary=>1,
        eol=>"\n",
    });
    my $header = $csv->getline($in);
    
    while (my $row_in=$csv->getline($in)) {
        $skus->{$row_in->[1]} = 1;
    }
}

my $unaffected = {};
my $intersect = {};
while (my $file = $dlqdir->next) {
    next if $file->is_dir;
    my $in = $file->slurp;
    next unless ($in =~ m/type:item_moved/g);
    while ($in =~ m/(\d{1,7}-\d{3,4})/g) {
        if ($skus->{$1}){
            $intersect->{$1} = 1;
        } else {
            $unaffected->{$1} = 1;
        }
    }
}

print "Unaffected " . (scalar keys %$unaffected) . "\n";
print "Affected " . (scalar keys %$intersect) . "\n";
