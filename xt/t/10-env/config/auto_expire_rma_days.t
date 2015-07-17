#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 CANDO-109: Checks Various Settings to do with Auto Expirations of RMAs for Returns and Exchanges

This will test the following settings in the Config file:

* That the number of days for auto expiry of returns is 45 days
* That the number of days for auto expiry for exchanges is 45 days

=cut

use Data::Dump qw( pp );


use Test::XTracker::Data;

use_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    auto_expire_rma_days
                                ) );
can_ok( 'XTracker::Config::Local', qw(
                                    config_var
                                    auto_expire_rma_days
                                ) );

my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Sanity Check' );

# get all Sales Channels
my @channels    = $schema->resultset('Public::Channel')->search( {}, { order_by => 'id' } )->all;

foreach my $channel ( @channels ) {
    note "Sales Channel: ".$channel->name;

    note "testing 'auto_expire_rma_days' function";
    cmp_ok( auto_expire_rma_days( $channel, 'return' ), '==', 45, "Using Channel Object - Auto RMA Expiry days for Returns is as expected: 45" );
    cmp_ok( auto_expire_rma_days( $channel->business->config_section, 'return' ), '==', 45, "Using Config Section - Auto RMA Expiry days for Returns is as expected: 45" );

    cmp_ok( auto_expire_rma_days( $channel, 'return' ), '==', 45, "Using Channel Object - Auto RMA Expiry days for Exchange is as expected: 45" );
    cmp_ok( auto_expire_rma_days( $channel->business->config_section, 'return' ), '==', 45, "Using Config Section - Auto RMA Expiry days for Exchange is as expected: 45" );

}

done_testing;
