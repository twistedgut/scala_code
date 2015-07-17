#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Data::Dump qw/pp/;
use FindBin::libs;

use Test::XTracker::RunCondition
    dc       => [ qw( DC1 DC2 ) ];

use Test::XTracker::Data;

use XTracker::Database::Shipment qw/ get_address_shipping_charges /;
use XTracker::Constants::FromDB qw/ :channel /;

# populate the postcode/country
my $test_cases = {
    DC1 => [
        {
            name => 'Disabled NAP Premier 3',
            setup => {
                channel => 'NAP-INTL',
                address => {
                    postcode => 'E3 8PD',
                    country => 'United Kingdom',
                },
            },
            expected => {
                absent_sku => '900001-001',
            },
        },
        {
            name => 'Disabled NAP Premier 2',
            setup => {
                channel => 'NAP-INTL',
                address => {
                    postcode => 'E2 8PD',
                    country => 'United Kingdom',
                },
            },
            expected => {
                absent_sku => '900002-001',
            },
        },
        {
            name => 'Disabled NAP Premier 1',
            setup => {
                channel => 'NAP-INTL',
                address => {
                    postcode => 'W11 8PD',
                    country => 'United Kingdom',
                },
            },
            expected => {
                absent_sku => '900005-001',
            },
        },
        {
            name => 'Disabled MRP Premier 3',
            setup => {
                channel => 'MRP-INTL',
                address => {
                    postcode => 'E3 8PD',
                    country => 'United Kingdom',
                },
            },
            expected => {
                absent_sku => '910001-001',
            },
        },
        {
            name => 'Disabled MRP Premier 2',
            setup => {
                channel => 'MRP-INTL',
                address => {
                    postcode => 'E2 8PD',
                    country => 'United Kingdom',
                },
            },
            expected => {
                absent_sku => '910002-001',
            },
        },
        {
            name => 'Disabled MRP Premier 1',
            setup => {
                channel => 'MRP-INTL',
                address => {
                    postcode => 'W11 8PD',
                    country => 'United Kingdom',
                },
            },
            expected => {
                absent_sku => '910005-001',
            },
        },
    ],
    DC2 => [
        {
            name => 'Disabled NAP New York Metro Area Same Day',
            setup => {
                channel => 'NAP-AM',
                address => {
                    postcode => '10010',
                    country => 'United States',
                },
            },
            expected => {
                absent_sku => '900025-002',
            },
        },
        {
            name => 'Disabled MRP New York Metro Area Same Day',
            setup => {
                channel => 'MRP-AM',
                address => {
                    postcode => '10010',
                    country => 'United States',
                },
            },
            expected => {
                absent_sku => '910025-001',
            },
        },
    ],
};

my $dc = Test::XTracker::Data->whatami;
my $schema = Test::XTracker::Data->get_schema;
my $dbh = Test::XTracker::Data->get_dbh;

foreach my $test_case (@{$test_cases->{$dc}}) {
    my $setup = $test_case->{setup};
    my $expected = $test_case->{expected};
    my $channel_name = $setup->{channel};
    my $channel = $schema->resultset('Public::Channel')->find_by_web_name(
        $channel_name);
    die "Cannot not find channel using $channel_name" if (!$channel);

    my %shipping_charges = get_address_shipping_charges(
        $dbh,
        $channel->id,
        $setup->{address},
    );
    if ($expected->{absent_sku}) {
        my @found = grep { $_->{sku} eq $expected->{absent_sku} }
            values %shipping_charges;
        is(scalar @found, 0, 'not found skus - '. scalar @found);
    }
}

done_testing;
