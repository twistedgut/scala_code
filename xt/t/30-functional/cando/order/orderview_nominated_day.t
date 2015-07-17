#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;


use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Database qw( :common );


test_prefix("Setup: framework");
my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
        'Test::XT::Flow::CustomerCare',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Packing',
        'Fulfilment/Picking',
        'Fulfilment/Selection',
        'Customer Care/Order Search',
        'Customer Care/Customer Search',
    ]},
    dept => 'Distribution'
});
$framework->mech->force_datalite(1);


test_prefix("Setup: order shipment");

my $channel = Test::XTracker::Data->channel_for_business(name => "NAP");

my $nominated_day_times  = Test::XTracker::Data::Order->nominated_day_times(1, $channel);
my $import_dispatch_time = $nominated_day_times->{import_dispatch_time};
my $dispatch_time        = $nominated_day_times->{nominated_dispatch_time};
my $delivery_date        = $nominated_day_times->{nominated_delivery_date};

note "Using times delivery_date ($delivery_date), dispatch_time (" . $dispatch_time->strftime("%Y-%m-%d %H:%M %Z") . ")\n";


my $test_cases = [
    {
        description => "No nominated day",
        setup => {
            nominated_delivery_date => undef,
            nominated_dispatch_time => undef,
        },
        expected => {
            nominated_delivery_date => undef,
            nominated_dispatch_time => undef,
        }
    },
    {
        description => "Nominated day specified",
        setup => {
            nominated_delivery_date => $delivery_date,
            nominated_dispatch_time => $import_dispatch_time,
        },
        expected => $nominated_day_times,
    },
];

for my $case (@$test_cases) {
    test_prefix($case->{description});
    my $setup = $case->{setup};
    my $expected = $case->{expected};

    my ($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 1 });
    my $order_data = $framework->flow_db__fulfilment__create_order_picked(
        channel  => $channel,
        products => $pids,
    );

    my $shipment = $order_data->{shipment_object};
    note "Set the nominated_day on the Shipment (" . $shipment->id . ")";
    $shipment->update({
        nominated_delivery_date => $setup->{nominated_delivery_date},
        nominated_dispatch_time => $setup->{nominated_dispatch_time},
    });

    $framework->flow_mech__customercare__orderview($order_data->{order_object}->id);
    my $shipment_details = $framework->mech->as_data()->{meta_data}->{"Shipment Details"};


    if(my $delivery_date = $expected->{nominated_delivery_date}) {
        my $expected_date = $delivery_date->strftime("%d-%m-%Y");
        is(
            $shipment_details->{"Nominated Delivery Date"},
            $expected_date,
            "Nominated Delivery Date is ($expected_date)",
        );
    }
    else {
        is(
            $shipment_details->{"Nominated Delivery Date"},
            "",
            "Nominated Delivery Date is blank",
        );
    }

}

# warn &p([$shipment_details]); use Data::Printer;




done_testing();
