#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;


use Test::XTracker::Data;

# Check that the config file settings, database records and the mode the
# tests are running in are all consistent - if this fails then something
# is probably configured incorrectly

my $name = Test::XTracker::Data->whatami();
note "| I AM | $name |";
my $expected_channel_suffix = {
    DC1 => 'INTL', DC2 => 'AM', DC3 => 'APAC',
}->{ $name };

for my $channel ( Test::XTracker::Data->get_schema->resultset('Public::Channel')->search() ) {
    my $channel_name = $channel->name;
    is( $channel->distrib_centre->name,
        $name, "Distribution centre name correct for $channel_name" );
    like( $channel->web_name, qr/-$expected_channel_suffix/,
        "Web name looks reasonable for $channel_name" );
}

done_testing;

