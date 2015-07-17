#!/usr/bin/env perl
use NAP::policy "tt", "test";
# Add DC3 when it gets a Nominated Day Shipping Charge
use Test::XTracker::RunCondition( dc => [ "DC1", "DC2" ] );

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use XTracker::Config::Local qw( config_var );
use XT::Data::DateStamp;
use XT::DC::Messaging::Producer::Shipping::DeliveryDateRestriction;

use Test::RoleHelper;
my $test_helper = Test::RoleHelper->new_with_roles(
    "Test::Role::NominatedDay::WithRestrictedDates",
);

my $amq = Test::XTracker::MessageQueue->new({schema=>$test_helper->schema});
my $destination = "/topic/shipping_info";

my $begin_date  = XT::Data::DateStamp->from_string("2010-01-01");
my $end_date    = XT::Data::DateStamp->from_string("2010-01-02");


for my $channel_row (Test::XTracker::Data->get_web_channels->all) {

    note "restricted_dates without restriction for " . $channel_row->name;
    $test_helper->with_emptied_restriction(
        sub {
            test_send([], $channel_row);
        },
    );

    note "restricted_dates with restriction";
    $test_helper->with_emptied_restriction(
        sub {
            note "*** Setup";
            my $shipping_charge_row = $test_helper->shipping_charge_rs->is_nominated_day->search({
                channel_id => $channel_row->id,
            })->first;
            my $restricted_date = $test_helper->restricted_date({
                date               => $begin_date,
                shipping_charge_id => $shipping_charge_row->id,
            });
            $restricted_date->restrict($test_helper->operator, "Change Reason");

            note "*** Test";
            test_send(
                [
                    {
                        date                => "$begin_date",
                        restriction_type    => $restricted_date->restriction_type,
                        shipping_charge_sku => $shipping_charge_row->sku,
                    },
                ],
                $channel_row,
            );
        },
    );
}

sub test_send {
    my ($expected_restricted_dates, $channel_row) = @_;

    $amq->clear_destination($destination);

    my $message = {
        begin_date  => $begin_date,
        end_date    => $end_date,
        channel_row => $channel_row,
    };
    lives_ok(
        sub {
            $amq->transform_and_send(
                "XT::DC::Messaging::Producer::Shipping::DeliveryDateRestriction",
                $message
            )
        },
        "Can send valid message",
    );

    $amq->assert_messages({
        destination  => $destination,
        assert_header => superhashof({
            type         => "ShippingRestrictedDays",
            channel_id   => $channel_row->id,
            channel_name => $channel_row->website_name,
        }),
        assert_body => superhashof({
            channel => $channel_row->website_name,
            window  => {
                begin_date => "$begin_date",
                end_date   => "$end_date",
            },
            restricted_dates => $expected_restricted_dates,
        }),
    },"message matches");
}

done_testing;
