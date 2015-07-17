#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition export => ['$distribution_centre'];

use Test::More::Prefix qw/ test_prefix /;
use Test::Exception;

use Test::XTracker::Hacks::TxnGuardRollback;
use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Mock::DHL::XMLRequest;
use Test::XTracker::OrderImporter;
use Test::XTracker::Utils;

use XT::Data::DateStamp;


my $schema = Test::XTracker::Data->get_schema;

my $count = $schema->resultset('Public::ShippingCharge')->search({ latest_nominated_dispatch_daytime => { '!=', undef }} )->count;
if( !$count > 0 ) {
    #nominated day delivery is not set for any of the sku's
    #so skip this test for dc3
    plan skip_all => "Skipping Test as nominated day delivery functionality is not switched 'On'";
}

sub nominated_day_fields_are_parsed {

    my $channel_parser_test_cases = Test::XTracker::OrderImporter->channel_parser_test_cases->{$distribution_centre};
    for my $channel_parser_case (@$channel_parser_test_cases) {

        my $channel_name = $channel_parser_case->{channel_name};
        my $channel = Test::XTracker::Data->channel_for_business(name => $channel_name);

        my $morning_daytime_hours = 11;
        my $morning_daytime = "$morning_daytime_hours:00:00";
        ok(
            my $morning_nominated_day_shipping_charge =
                $schema->resultset("Public::ShippingCharge")->search({
                    latest_nominated_dispatch_daytime => $morning_daytime,
                })->first,
            "Got Nominated Day Morning/Daytime Shipping Charge ",
        );

        my $import_dispatch_date = DateTime->now()->add(hours => 24)->truncate(to => "day");
        $import_dispatch_date->set_time_zone("Europe/London");

        my $dispatch_time = DateTime->new(
            year      => $import_dispatch_date->year,
            month     => $import_dispatch_date->month,
            day       => $import_dispatch_date->day,
            time_zone => $channel->timezone, # TZ of DC
        );
        $dispatch_time->add(hours => $morning_daytime_hours);

        my $earliest_selection_time = sub {
            my ( $carrier ) = @_;
            return $dispatch_time->clone
                ->subtract(days => 1)
                ->truncate(to => "day")
                ->add($carrier->last_pickup_daytime);
        };

        my $delivery_date = $dispatch_time->clone->add(hours => 24)
            # Simplification, should really be the customer address' TZ
            ->set_time_zone($channel->timezone)
            ->truncate(to => "day");

        my $test_cases = [
            {
                description => "No nominated day",
                setup => {
                    nominated_delivery_date => undef,
                    nominated_dispatch_date => undef,
                    shipping_sku            => undef,
                },
                expected => {
                    nominated_delivery_date  => undef,
                    nominated_dispatch_time  => undef,
                    nominated_earliest_selection_time => sub { undef },
                }
            },
            {
                description => "Nominated day",
                setup => {
                    nominated_delivery_date => $delivery_date,
                    nominated_dispatch_date => $import_dispatch_date,
                    shipping_sku            => $morning_nominated_day_shipping_charge->sku,
                },
                expected => {
                    nominated_delivery_date  => XT::Data::DateStamp->from_datetime($delivery_date),
                    nominated_dispatch_time  => $dispatch_time,
                    nominated_earliest_selection_time => $earliest_selection_time,
                }
            },
        ];

        for my $case (@$test_cases) {

            my $setup = $case->{setup};
            my $expected = $case->{expected};
            note("\n\n\n*** $case->{description} for ($channel_name), and ($channel_parser_case->{parser_class_name}) ***");
            test_prefix("Setup");
            my $data_orders = Test::XTracker::OrderImporter->import_order(
                $channel_parser_case->{parser_class_name},
                $channel_name,
                {
                    order => {
                        nominated_day => {
                            nominated_delivery_date => $setup->{nominated_delivery_date},
                            nominated_dispatch_date => $setup->{nominated_dispatch_date},
                        },
                        shipping_sku => $setup->{shipping_sku},
                    },
                },
            );
            is(@$data_orders, 1, "Got the one order");
            my $data_order = $data_orders->[0];

            # Must run digest to get the $data_order object in a
            # usable state for e.g. nominated_dispatch_date.
            my $mock = Test::XTracker::Mock::DHL::XMLRequest->setup_mock(
                [ { service_code => 'LON' } ],
            );
            my $order_row = $data_order->digest();


            test_prefix("Test");
            note("* Test parsed Data::Order");
            is(
                ($data_order->nominated_delivery_date // "") . "",
                ($expected->{nominated_delivery_date} // "") . "",
                "Order nominated_delivery_date is " . val($expected->{nominated_delivery_date}),
            );
            is(
                $data_order->nominated_dispatch_time,
                $expected->{nominated_dispatch_time},
                "Order nominated_dispatch_time is " . val($expected->{nominated_dispatch_time}),
            );


            note("* Test imported Shipment row");
            my $shipment_row = $order_row->get_standard_class_shipment;
            test_prefix("");
            if ($expected->{nominated_dispatch_time}) {
                TODO: {
                    local $TODO = "Time zone of db session isn't set to the expected one (the TZ of the DC, so America/New_York for DC2), so it's not setting the correct TZ when inflating timestamps";
                    is(
                        $shipment_row->nominated_dispatch_time->offset,
                        $expected->{nominated_dispatch_time}->offset,
                        "Shipment nominated_dispatch_time TZ offset is " . val($expected->{nominated_dispatch_time}->offset),
                    );
                }
            }

            is(
                datetime_as_date($shipment_row->nominated_delivery_date),
                $expected->{nominated_delivery_date},
                "Shipment nominated_delivery_date is " . val($expected->{nominated_delivery_date}),
            );
            is(
                $shipment_row->nominated_dispatch_time,
                $expected->{nominated_dispatch_time},
                "Shipment nominated_dispatch_time is " . val($expected->{nominated_dispatch_time}),
            );
            my $expected_nominated_earliest_selection_time
                = $expected->{nominated_earliest_selection_time}($shipment_row->carrier);
            is(
                $shipment_row->nominated_earliest_selection_time,
                $expected_nominated_earliest_selection_time,
                "Shipment nominated_earliest_selection_time is " . val($expected_nominated_earliest_selection_time),
            );

        }
    }
}

sub datetime_as_date {
    my ($datetime) = @_;
    $datetime or return undef;
    return $datetime->ymd;
}

sub val {
    return "(" . (shift // "undef") . ")";
}

# Disable the txn_do to leave the shipment row in the db
# $schema->txn_do( sub {
    nominated_day_fields_are_parsed();

#     $schema->txn_rollback;
# });

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;
