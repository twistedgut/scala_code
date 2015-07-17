#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::RunCondition    dc => 'DC1';

use XTracker::Constants::FromDB qw( :channel :shipment_type );
use vars qw/
    $CHANNEL__NAP_INTL
    $CHANNEL__OUTNET_INTL
    $CHANNEL__MRP_INTL
    $CHANNEL__JC_INTL

    $SHIPMENT_TYPE__PREMIER
    $SHIPMENT_TYPE__DOMESTIC
    $SHIPMENT_TYPE__INTERNATIONAL
    $SHIPMENT_TYPE__INTERNATIONAL_DDU
/;
use Test::More::Prefix qw/ test_prefix /;
use XTracker::Database 'xtracker_schema';
use XTracker::Database::Shipment qw( get_shipment_shipping_account );


my $schema = xtracker_schema;
my $dbh = $schema->storage->dbh;

eval {
    _get_shipment_shipping_account($dbh,$schema);
    1;
} or fail( "Died: $@");

done_testing();

#use Carp::Always;
sub _get_shipment_shipping_account {
    my ($dbh, $schema) = @_;


    my $common_channel_test = [
        # International
        {
            shipping_charge_class     => "Air",
            shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL,
            expected_shipping_account => "International",
        },
        {
            shipping_charge_class     => "Ground",
            shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL,
            expected_shipping_account => "International Road",
        },

        {
            shipping_charge_class     => "Air",
            shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL_DDU,
            expected_shipping_account => "International",
        },
        {
            shipping_charge_class     => "Ground",
            shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL_DDU,
            expected_shipping_account => "International Road",
        },

        # Domestic
        {
            shipping_charge_class     => "Air",
            shipment_type_id          => $SHIPMENT_TYPE__DOMESTIC,
            expected_shipping_account => "Domestic",
        },

        {
            shipping_charge_class     => "Ground",
            shipment_type_id          => $SHIPMENT_TYPE__DOMESTIC,
            expected_shipping_account => "Domestic",
        },

        # Premier
        {
            shipping_charge_class     => "Air",
            shipment_type_id          => $SHIPMENT_TYPE__PREMIER,
            expected_shipping_account => "Unknown",
        },
        {
            shipping_charge_class       => "Ground",
            shipment_type_id          => $SHIPMENT_TYPE__PREMIER,
            expected_shipping_account => "Unknown",
        },
    ];

    # Missing tests:
    # - AM channels
    # - shipping_account__country entries, for DC2 United States
    my $channel_tests = {
        $CHANNEL__NAP_INTL => $common_channel_test,

        $CHANNEL__MRP_INTL => $common_channel_test,

        $CHANNEL__OUTNET_INTL => [
            # International
            {
                shipping_charge_class     => "Air",
                shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL,
                expected_shipping_account => "International",
            },
            {
                shipping_charge_class     => "Ground",
                shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL,
                expected_shipping_account => "International Road",
            },

            {
                shipping_charge_class     => "Air",
                shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL_DDU,
                expected_shipping_account => "International",
            },
            {
                shipping_charge_class     => "Ground",
                shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL_DDU,
                expected_shipping_account => "International Road",
            },

            # Domestic
            {
                shipping_charge_class     => "Air",
                shipment_type_id          => $SHIPMENT_TYPE__DOMESTIC,
                expected_shipping_account => "Domestic",
            },

            {
                shipping_charge_class     => "Ground",
                shipment_type_id          => $SHIPMENT_TYPE__DOMESTIC,
                expected_shipping_account => "Domestic",
            },

            # Premier
            # Outnet doesn't support Premier
            # {
            #     shipping_charge_class     => "Air",
            #     shipment_type_id          => $SHIPMENT_TYPE__PREMIER,
            #     expected_shipping_account => "Unknown",
            # },
            # {
            #     shipping_charge_class     => "Ground",
            #     shipment_type_id          => $SHIPMENT_TYPE__PREMIER,
            #     expected_shipping_account => "Unknown",
            # },
        ],

        $CHANNEL__JC_INTL => [
            # International
            {
                shipping_charge_class     => "Air",
                shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL,
                expected_shipping_account => "International",
            },
            {
                shipping_charge_class     => "Ground",
                shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL,
                expected_shipping_account => "International", # JC doesn't have International Road
            },

            {
                shipping_charge_class     => "Air",
                shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL_DDU,
                expected_shipping_account => "International",
            },
            {
                shipping_charge_class     => "Ground",
                shipment_type_id          => $SHIPMENT_TYPE__INTERNATIONAL_DDU,
                expected_shipping_account => "International", # JC doesn't have International Road
            },

            # Domestic
            {
                shipping_charge_class     => "Air",
                shipment_type_id          => $SHIPMENT_TYPE__DOMESTIC,
                expected_shipping_account => "Domestic",
            },

            {
                shipping_charge_class     => "Ground",
                shipment_type_id          => $SHIPMENT_TYPE__DOMESTIC,
                expected_shipping_account => "Domestic",
            },

            # Premier
            {
                shipping_charge_class     => "Air",
                shipment_type_id          => $SHIPMENT_TYPE__PREMIER,
                expected_shipping_account => "Unknown",
            },
            {
                shipping_charge_class       => "Ground",
                shipment_type_id          => $SHIPMENT_TYPE__PREMIER,
                expected_shipping_account => "Unknown",
            },
        ],
    };

    for my $channel_id (sort keys %$channel_tests) {
        my $channel_name = $schema->find_col(Channel => $channel_id, "web_name");
        test_prefix("($channel_id: $channel_name):");

        my $tests = $channel_tests->{$channel_id};
        for my $test (@$tests) {
            test_shipping_account_id($test, $channel_id);
        }
    }
    test_prefix("");
}

sub test_shipping_account_id {
    my ($args, $channel_id) = @_;
    note  "Testing channel ($channel_id), ($args->{expected_shipping_account}) from charge class ($args->{shipping_charge_class}), shipment_type_id ($args->{shipment_type_id}) ";

    my $expected_shipping_account_id
          = $schema->resultset("Public::ShippingAccount")->search({
              channel_id => $channel_id,
              name       => $args->{expected_shipping_account},
          })->single->id;

    my $shipment_type = $schema->find_col(ShipmentType => $args->{shipment_type_id}, "type");
    note "Testing shipment_type($shipment_type), " . p($args) . "\n";

    my $shipping_account_id = get_shipment_shipping_account(
        $dbh,
        {
            channel_id       => $channel_id,
            country          => "UK",
            item_data        => {},
            shipping_class   => $args->{shipping_charge_class},
            shipment_type_id => $args->{shipment_type_id},
        },
    );
    is(
        $shipping_account_id,
        $expected_shipping_account_id,
        "Got correct shipping account ($expected_shipping_account_id)",
    );
}

