#!/usr/bin/env perl
use NAP::policy "tt", 'test';
#
# Test the Public::Channel methods
#
use FindBin::libs;


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::Mechanize::PurchaseOrder;
use XTracker::Constants::FromDB qw(
    :channel
);

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, 'XTracker::Schema', 'Got Schema' );

my $drop_down_options = $schema->resultset('Public::Channel')->drop_down_options;
isa_ok( $drop_down_options, 'XTracker::Schema::ResultSet::Public::Channel', 'It is a Channel object' );

my $channel_data = Test::XTracker::Mechanize::PurchaseOrder->get_channel_order;

# Ensure there are the correct number of channels
is( $drop_down_options->count, scalar(@$channel_data), 'Correct number of channels' );

my $index = 0;
while (my $drop_down_option = $drop_down_options->next) {
    is( $drop_down_option->id,      $channel_data->[$index]{id},    "Drop down $index ID" );
    is( $drop_down_option->name,    $channel_data->[$index]{name},  "Drop down $index Name" );
    $index++
}

done_testing;
1;
