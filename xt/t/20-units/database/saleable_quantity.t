#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Test::XTracker::Data;
use Time::HiRes 'gettimeofday','tv_interval';
use XTracker::Constants::FromDB '$VARIANT_TYPE__STOCK';

my $schema=Test::XTracker::Data->get_schema;
my (undef,$pids)=Test::XTracker::Data->grab_products();
my $product=$pids->[0]{product};

my $start = [gettimeofday];
my $details=$product->get_saleable_item_quantity_details;
my $stop = [gettimeofday];my $details_time=tv_interval($start,$stop);
my $summary=$product->get_saleable_item_quantity;
my $stop2 = [gettimeofday];my $summary_time=tv_interval($stop,$stop2);

note p $details;note "took $details_time\n";
note p $summary;note "took $summary_time\n";

my %channel_map =
    map { $_->id, $_->name } $schema->resultset('Public::Channel')->all;

for my $chid (keys %$details) {
    my $d_slot = $details->{$chid};
    my $s_slot = $summary->{$channel_map{$chid}};
    for my $v (keys %$d_slot) {
        my $d_sq = $d_slot->{$v}{$VARIANT_TYPE__STOCK}{saleable_quantity};
        my $s_sq = $s_slot->{$v};
        is($d_sq,$s_sq,
           "saleable quantity for variant $v on channel $chid is the same");
    }
}

done_testing();

