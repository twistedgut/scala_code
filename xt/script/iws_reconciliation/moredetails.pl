#!/opt/xt/xt-perl/bin/perl

=pod

Rough script to try to provide more insight into the results of the reconciliation
Tries to determine if channel transfers are to blame and then breaks differences down in some other potentially helpful ways

=cut

use strict;
use warnings;

use Path::Class;
use Text::CSV_XS;
use Data::Dump qw(pp);

my $big_diff = 4;

my $dir = @ARGV ? dir($ARGV[0]) : dir();
my $dump_all_discrepancy_skus = @ARGV && dir($ARGV[1]) ? 1 : 0;

#
# setup vars
#
my ($data, $sku_totals, $sku_totals_complete, $statistics, $explained);

#
# read data
#
_inhale_reconciliation_output();
#_inhale_reconciliation_input();

#
# gather stats
#
my ($source, $dest) = (keys %{$data->{xt}} < keys %{$data->{iws}})
                            ? ('xt','iws') : ('iws', 'xt'); # work on the smaller set
_transfer_failures();
_type_change();
_get_biguns();
_differences_summary();
_differences_by_sku();
_size_changes();

#
# output
#
#print pp($statistics->{'1. transfer_exact'});
print "=======\n";
print "summary\n";
print "=======\n";
foreach my $field (sort keys %$statistics){
    if (ref $statistics->{$field} eq 'ARRAY'){
        print $field . ' : ' . (scalar @{$statistics->{$field}}) . "\n";
    } else {
        print $field . ' : ' . $statistics->{$field} . "\n";
    }
}
if ($dump_all_discrepancy_skus){
    print join(',', map { "'$_'" } sort keys %$sku_totals);
}

# the subs
sub _inhale_reconciliation_output {
    foreach my $system ('xt', 'iws') {
        my $in=eval { $dir->file("skus_in_${system}_only-filtered.csv")->openr;};
        if ($@){$in = $dir->file("skus_in_${system}_only.csv")->openr;}
        my $csv=Text::CSV_XS->new({
            binary=>1,
            eol=>"\n",
        });
        my $header = $csv->getline($in);
        
        while (my $row_in=$csv->getline($in)) { 
            $data->{$system}->{$row_in->[1]}->{$row_in->[2]}->{$row_in->[0]} = [$row_in->[3], $row_in->[4], $row_in->[5]];
            $sku_totals->{$row_in->[1]}->{$system} += $row_in->[3] + $row_in->[4] + $row_in->[5];
            $sku_totals->{$row_in->[1]}->{"$system channels"}->{$row_in->[0]} = 1;
        }
    }
    {
        my $in=eval { $dir->file("skus_that_differ-filtered.csv")->openr;};
        if ($@){$in = $dir->file("skus_that_differ.csv")->openr;}
        my $csv=Text::CSV_XS->new({
            binary=>1,
            eol=>"\n",
        });
        my $header = $csv->getline($in);
        my %columns = ('unavailable'=> [3,4,5], 'allocated' => [6,7,8], 'available' => [9,10,11]);
        
        while (my $row_in=$csv->getline($in)) {
            while (my ($status, $index) = each %columns){
                next if $row_in->[$index->[2]] == 0;
                my $system = ( $row_in->[$index->[2]] > 0 ) ? 'iws' : 'xt';
                $data->{'excess_'.$system}->{$status}->{$row_in->[1]}->{$row_in->[2]}->{$row_in->[0]} = [@$row_in[@$index]];
                $sku_totals->{$row_in->[1]}->{'xt'} += $row_in->[$index->[0]];
                $sku_totals->{$row_in->[1]}->{'iws'} += $row_in->[$index->[1]];
                $sku_totals->{$row_in->[1]}->{'xt channels'}->{$row_in->[0]} = 1 if $row_in->[$index->[0]];
                $sku_totals->{$row_in->[1]}->{'iws channels'}->{$row_in->[0]} = 1 if $row_in->[$index->[1]];
            } 
        }   
    }       
}

sub _inhale_reconciliation_input {
    foreach my $system ('xt', 'iws') {
        my $in=$dir->file("${system}_stock_export.csv")->openr;
        my $csv=Text::CSV_XS->new({
            binary=>1,
            eol=>"\n",
        });
        $csv->getline($in) if $system eq 'xt'; # comment at top of file
        my $header = $csv->getline($in);
        
        while (my $row_in=$csv->getline($in)) {
            $sku_totals_complete->{$row_in->[1]}->{$system} += $row_in->[3] + $row_in->[4] + $row_in->[5];
            $sku_totals_complete->{$row_in->[1]}->{"$system channels"}->{$row_in->[0]} = 1;
        }
    }
}

sub _transfer_failures {
    foreach my $sku (sort keys %{$data->{$source}}){
        next unless $data->{$dest}->{$sku};
        foreach my $type ( sort keys %{$data->{$source}->{$sku}} ){
            next unless $data->{$dest}->{$sku}->{$type};
            
            foreach my $s_chan ( sort keys %{$data->{$source}->{$sku}->{$type}} ){
                foreach my $d_chan ( sort keys %{$data->{$dest}->{$sku}->{$type}} ){
                    die "Um that's the same everything for $sku, $type, $s_chan" if $s_chan eq $d_chan;
                    my $sq = join(',', @{ $data->{$source}->{$sku}->{$type}->{$s_chan}} );
                    my $dq = join(',', @{ $data->{$dest}->{$sku}->{$type}->{$d_chan}} );
                                    
                    if ( $sq eq $dq ){
                        _add_to_stats("1. transfer_exact $type", "$sku with type $type has same quantities on $s_chan on $source and $d_chan on $dest ($sq)");
                        _add_to_explained("1. transfer_exact $type", $sku, $type, $s_chan);
                        _add_to_explained("1. transfer_exact $type", $sku, $type, $d_chan);
                    } else {
                        _add_to_stats('1. transfer_out', "$sku with type $type has different quantities on $s_chan on $source ($sq) and $d_chan on $dest ($dq)");
                        _add_to_explained('1. transfer_out', $sku, $type, $s_chan);
                        _add_to_explained('1. transfer_out', $sku, $type, $d_chan);
                    }
                }
            }

        }
    }
}

sub _type_change {
    foreach my $sku (sort keys %{$data->{$source}}){
        next unless $data->{$dest}->{$sku};
        foreach my $s_type ( sort keys %{$data->{$source}->{$sku}} ){
            foreach my $chan ( sort keys %{$data->{$source}->{$sku}->{$s_type}} ){

                foreach my $d_type ( sort keys %{$data->{$dest}->{$sku}} ){
                    next unless $data->{$dest}->{$sku}->{$d_type}->{$chan};
                    die "Um that's the same everything for $sku, $s_type, $chan" if $s_type eq $d_type;
                    my $sq = join(',', @{ $data->{$source}->{$sku}->{$s_type}->{$chan}} );
                    my $dq = join(',', @{ $data->{$dest}->{$sku}->{$d_type}->{$chan}} );
                                    
                    if ( $sq eq $dq ){
                        _add_to_stats('1. type change exact', "$sku with on channel $chan has same quantities in type $s_type on $source and $d_type on $dest ($sq)");
                    } else {
                        _add_to_stats('1. type change out', "$sku with on channel $chan has different quantities in type $s_type on $source ($sq) and $d_type on $dest ($dq)");
                    }
                }
            }

        }
    }
}

sub _get_biguns {
    ## no critic(ProhibitDeepNests)
    foreach my $system ('xt', 'iws'){
        foreach my $sku (sort keys %{$data->{$system}}){
            foreach my $type ( sort keys %{$data->{$system}->{$sku}} ){
                foreach my $chan ( sort keys %{$data->{$system}->{$sku}->{$type}} ){
                    if ($data->{$system}->{$sku}->{$type}->{$chan}->[0] >= $big_diff ||
                        $data->{$system}->{$sku}->{$type}->{$chan}->[1] >= $big_diff ||
                        $data->{$system}->{$sku}->{$type}->{$chan}->[2] >= $big_diff) {
                        if (_is_explained($sku, $type, $chan)){
                            _add_to_stats('1. biguns_explained', "$system only file has big value in for $sku, $chan, $type (" . join(',', @{ $data->{$system}->{$sku}->{$type}->{$chan}} ) . ")");
                        } else {
                            _add_to_stats('1. biguns_unexplained', "$system only file has big value in for $sku, $chan, $type (" . join(',', @{ $data->{$system}->{$sku}->{$type}->{$chan}} ) . ")");
                        }
                    }
                }
            }
        }
    }
}

sub _differences_summary {
    ## no critic(ProhibitDeepNests)
    foreach my $system (keys %$data){
        if ($system =~ m/^excess_/){
            foreach my $status (keys %{$data->{$system}}){
                foreach my $sku (sort keys %{$data->{$system}->{$status}}){
                    foreach my $type ( sort keys %{$data->{$system}->{$status}->{$sku}} ){
                        foreach my $chan ( sort keys %{$data->{$system}->{$status}->{$sku}->{$type}} ){
                            push @{$statistics->{"$system $status skus"}},
                                 {"$sku of type $type in channel $chan has " . $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[2] . " extra" => $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[2]};
                            push @{$statistics->{"$system $status where larger is zero"}}, "$sku of type $type in channel $chan has " . join(',', @{$data->{$system}->{$status}->{$sku}->{$type}->{$chan}})
                                if ($data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[0] < 0 && $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[1] == 0) ||
                                   ($data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[1] < 0 && $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[0] == 0);

                            push @{$statistics->{"$system $status where smaller is zero"}}, "$sku of type $type in channel $chan has " . join(',', @{$data->{$system}->{$status}->{$sku}->{$type}->{$chan}})
                                if ($data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[0] > 0 && $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[1] == 0) ||
                                   ($data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[1] > 0 && $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[0] == 0);

                            push @{$statistics->{"$system $status where one is negative"}}, "$sku of type $type in channel $chan has " . join(',', @{$data->{$system}->{$status}->{$sku}->{$type}->{$chan}})
                                if $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[0] < 0 || $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[1] < 0;

                            push @{$statistics->{"$system $status where both positive"}}, "$sku of type $type in channel $chan has " . join(',', @{$data->{$system}->{$status}->{$sku}->{$type}->{$chan}})
                                if $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[0] >= 0 && $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[1] >= 0;

                            $statistics->{"$system $status total_units"} += $data->{$system}->{$status}->{$sku}->{$type}->{$chan}->[2];
                        }
                    }
                }
            }
        } else {
            my %columns = ('unavailable' => 0, 'allocated' => 1, 'available' => 2);
            foreach my $sku (sort keys %{$data->{$system}}){
                foreach my $type ( sort keys %{$data->{$system}->{$sku}} ){
                    foreach my $chan ( sort keys %{$data->{$system}->{$sku}->{$type}} ){
                        while (my ($status, $index) = each %columns){
                            next unless $data->{$system}->{$sku}->{$type}->{$chan}->[$index];
                            push @{$statistics->{"only $system $status skus"}},
                                 "$sku of type $type in channel $chan has " . $data->{$system}->{$sku}->{$type}->{$chan}->[$index] . " extra";

                            if ($data->{$system}->{$sku}->{$type}->{$chan}->[$index] < 0){
                                push @{$statistics->{"only $system $status where it is negative"}}, "$sku of type $type in channel $chan has $data->{$system}->{$sku}->{$type}->{$chan}->[$index] items";
                            } else {
                                push @{$statistics->{"only $system $status where it is positive"}}, "$sku of type $type in channel $chan has $data->{$system}->{$sku}->{$type}->{$chan}->[$index] items";
                            }
                            $statistics->{"only $system $status total_units"} += $data->{$system}->{$sku}->{$type}->{$chan}->[$index];
                        }
                    }
                }
            }
        }
    }
}

sub _differences_by_sku {
    foreach my $sku (sort keys %$sku_totals){
        $sku_totals->{$sku}->{xt} ||= 0;
        $sku_totals->{$sku}->{iws} ||= 0;
        if ($sku_totals->{$sku}->{xt} == $sku_totals->{$sku}->{iws}){
            _add_to_stats('overall_skus_matching', $sku);
        } elsif ($sku_totals->{$sku}->{xt} < $sku_totals->{$sku}->{iws}) {
            _add_to_stats('overall_skus_iws_more', $sku);
        } elsif ($sku_totals->{$sku}->{xt} > $sku_totals->{$sku}->{iws}) {
            _add_to_stats('overall_skus_xt_more', $sku);
        } else {
            _add_to_stats('overall_skus_wtf', $sku);
        }

        my $xt_chan_count = keys %{$sku_totals->{$sku}->{'xt channels'}};
        my $iws_chan_count = keys %{$sku_totals->{$sku}->{'iws channels'}};
        if ($xt_chan_count > 1){
             _add_to_stats('overall skus on > 1 channel xt', $sku);
        } 
        if ($iws_chan_count > 1){ 
             _add_to_stats('overall skus on > 1 channel iws', $sku);
        }
        if ($xt_chan_count == 1){
             _add_to_stats('overall skus on == 1 channel xt', $sku);
        } 
        if ($iws_chan_count == 1){
             _add_to_stats('overall skus on == 1 channel iws', $sku);
        }
        $statistics->{"overall skus count channel distribution xt $xt_chan_count"} += 1;
        $statistics->{"overall skus count channel distribution iws $iws_chan_count"} += 1;
    }
}

sub _size_changes {
    my $prods = {};
    # hmm. how do we do this
    foreach my $sku (keys %$sku_totals_complete){
        my ($prod, $size) = split(/-/, $sku);
        $prods->{$prod}++ if (defined $sku_totals_complete->{$sku}->{xt} && ! defined $sku_totals_complete->{$sku}->{iws} );
        $prods->{$prod}-- if (! defined $sku_totals_complete->{$sku}->{xt} && defined $sku_totals_complete->{$sku}->{iws} );
    }
    $statistics->{'1. size change affected'} = [grep {$prods->{$_} == 0} keys %$prods];
}


# helpers
sub _add_to_stats {
    my ($stat, $message) = @_;
    push @{$statistics->{$stat}}, $message;
}
sub _add_to_explained {
    my ($stat, $sku, $type, $channel) = @_;
    die "Already explained this item as '" . $explained->{$sku}->{$type}->{$channel} . "'"
        if $explained->{$sku}->{$type}->{$channel};
    $explained->{$sku}->{$type}->{$channel} = $stat;
}
sub _is_explained {
    my ($sku, $type, $channel) = @_;
    return exists $explained->{$sku}->{$type}->{$channel};
}

