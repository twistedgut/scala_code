#!/opt/xt/xt-perl/bin/perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)

=pod

Compare reconciliation with previous reports

=cut

use strict;
use warnings;

use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use Path::Class;
use Carp qw( croak );
use Text::CSV_XS;
use Data::Dump qw(pp);

my $dir1 = @ARGV ? dir($ARGV[0]) : dir();
my $dir2 = @ARGV ? dir($ARGV[1]) : dir();
my $display = $ARGV[2] // 'full';

die unless ($dir1 && $dir2);

# read data
my @data;
foreach my $dir ($dir1, $dir2){
    my $data = {};
    foreach my $system ('xt', 'iws') {
        my $in = eval {$dir->file("skus_in_${system}_only-filtered.csv")->openr;};
        if (!$in){ $in = eval { $dir->file("skus_in_${system}_only.csv")->openr;};}
        if (!$in){
            print "SKIPPING : $@";
            next;
        }

        my $csv=Text::CSV_XS->new({
            binary=>1,
            eol=>"\n",
        });
        my $header = $csv->getline($in);
        
        while (my $row_in=$csv->getline($in)) {
            $data->{$system . ' : ' . $row_in->[1] . ' : ' . $row_in->[2] . ' : ' . $row_in->[0]} = $row_in->[3] . ',' . $row_in->[4] . ',' . $row_in->[5];
        }
    }
    {
        my $in = eval{$dir->file("skus_that_differ-filtered.csv")->openr;};
        if (!$in){ $in = eval { $dir->file("skus_that_differ.csv")->openr;};}
        if (!$in){
            print "SKIPPING : $@";
            next;
        }
        my $csv=Text::CSV_XS->new({
            binary=>1,
            eol=>"\n",
        });
        my $header = $csv->getline($in);

        while (my $row_in=$csv->getline($in)) {
            $data->{'different' . ' : ' . $row_in->[1] . ' : ' . $row_in->[2] . ' : ' . $row_in->[0]} = 1;
        }
    }
    push @data, $data;
}

my $stats;
foreach my $key (sort keys %{$data[0]}){
    my ($type) = ( $key =~ m/^([^\s]+)/ );

    if ($data[1]->{$key} && $data[0]->{$key} eq $data[1]->{$key}){
        push @{$stats->{"in both '$type' file, and same quantities"}}, $key . ' => ' . $data[0]->{$key};
    } elsif($data[1]->{$key}){
        push @{$stats->{"in both '$type' file, but different quantities"}}, $key . ' => ' . $data[0]->{$key} . ' => ' . $data[1]->{$key};
    } else {
        push @{$stats->{"only in first '$type' file"}}, $key . ' => ' . $data[0]->{$key};
    }
}
foreach my $key (sort keys %{$data[1]}){
    unless ($data[0]->{$key}){
        my ($type) = ( $key =~ m/^([^\s]+)/ );
        push @{$stats->{"only in second '$type' file"}}, $key . ' => ' . $data[1]->{$key};
    }
}

if ($display =~ m/bad/){
    my $filtered = {map {$_ => $stats->{$_}} grep {not m/both .* same/} keys $stats};
    $stats = $filtered;
}
if ($display =~ m/stats/){
    foreach my $key (sort keys %$stats){
        print "$key : " . (scalar @{$stats->{$key}}) . "\n";    
    }
} else {
    pp($stats);
}
print "display was $display";
