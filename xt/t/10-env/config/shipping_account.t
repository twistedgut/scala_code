#!/usr/bin/env perl
#
use NAP::policy "tt",     'test';

=head2 Checks Shipping Account

This will test functions, methods & configuration in connection with Shipping Accounts

    * Tests the 'shipping_account__country' table is populated correctly, this table
      is used primarly by UPS Carrier Automation to get the correct Shipping Account
      for a Shipment Country, but can be used to give an exact Shipping Account for
      any Country if required.


please add more here when needed

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition
                            export => [ qw( $distribution_centre ) ];


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Sanity Check' );

# lists all expected countries/regions
# that should have Tax included
my %expected    = (
    DC1 => {
        shipping_account_country    => {},
    },
    DC2 => {
        shipping_account_country    => {
            NAP     => {
                'United States' => {
                        account_name    => 'Domestic',
                        carrier_name    => 'UPS',
                    },
            },
            OUTNET  => {
                'United States' => {
                        account_name    => 'Domestic',
                        carrier_name    => 'UPS',
                    },
            },
            MRP     => {
                'United States' => {
                        account_name    => 'Domestic',
                        carrier_name    => 'UPS',
                    },
            },
            JC      => {
                'United States' => {
                        account_name    => 'Domestic',
                        carrier_name    => 'UPS',
                    },
            },
        },
    },
    DC3 => {
        shipping_account_country    => {},
    },
);
my $expected_dc = $expected{ $distribution_centre };
if ( !$expected_dc ) {
    fail( "NO Expected Outcomes have been configured in this Test for DC: ${distribution_centre}" );
    done_testing;
    exit;
}

note "TESTING: Shipping Account Country";
my %ship_acnt_ctry  = map {
        $_->channel->business->config_section => {
            $_->country => {
                account_name    => $_->shipping_account->name,
                carrier_name    => $_->shipping_account->carrier->name,
            }
        }
    } $schema->resultset('Public::ShippingAccountCountry')->all;
is_deeply( \%ship_acnt_ctry, $expected_dc->{shipping_account_country}, "'shipping_account__country' populated as expected" );


done_testing;
