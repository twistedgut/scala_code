#!/usr/bin/env perl
use strict;
use warnings;
#use autodie ':all';
use Path::Class;
use Text::CSV_XS;
use List::Util 'sum';

sub filter_3 {
    my ($row) = @_;

    return [] if sum(@$row[3,4,5]) == 0;
    return $row;
}

sub filter_9 {
    my ($row) = @_;

    return [] if sum(@$row[5,8,11]) == 0;
    return $row;
}

my $dir = @ARGV ? dir($ARGV[0]) : dir();

my %files = (
    'skus_in_iws_only' => \&filter_3,
    'skus_in_xt_only' => \&filter_3,
    'skus_that_differ' => \&filter_9,
);

while (my ($basename,$filter) = each %files) {
    my $in=$dir->file("${basename}.csv")->openr;
    my $out=$dir->file("${basename}-filtered.csv")->openw;

    my $csv=Text::CSV_XS->new({
        binary=>1,
        eol=>"\n",
    });
    # keep the header
    $csv->print($out,$csv->getline($in));

    while (my $row_in=$csv->getline($in)) {
        my $row_out = $filter->($row_in);

        next unless @$row_out;

        $csv->print($out,$row_out);
    }
}
