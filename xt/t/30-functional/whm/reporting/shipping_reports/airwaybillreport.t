#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

airwaybillreport.t - Test the Airway Bill Report

=head1 DESCRIPTION

Unit test XTracker::Database::Reporting::outbound_airwaybill_report

Test the CSV file created by /Reporting/ShippingReports/AirwaybillReport

#TAGS checkruncondition reporting dhl ups nominatedday shipping loops whm

=cut

use FindBin::libs;

use Test::XTracker::RunCondition dc => ["DC1", "DC2"];

use DateTime;

use Test::Most "-Test::Deep";
use Test::More::Prefix qw/ test_prefix /;

use Test::XTracker::Data;
use XTracker::Database::Reporting qw( :ShippingReports ); # outbound_airwaybill_report
use XTracker::Database::Channel qw( get_channels );
use XT::Data::DateStamp;
use Test::XTracker::Mechanize;


my $schema      = Test::XTracker::Data->get_schema;

my $channel = Test::XTracker::Data->get_local_channel();
my $dbh = $schema->storage->dbh;

Test::XTracker::Data->set_department("it.god", "Shipping");
Test::XTracker::Data->grant_permissions("it.god", "Reporting", "Shipping Reports", 2);
my $mech = Test::XTracker::Mechanize->new;
$mech->do_login;

### Get carriers
my $carrier_rs;
if(Test::XTracker::Data->whatami eq 'DC1'){
    $carrier_rs = $schema->resultset('Public::Carrier')->search({
        name => { like => 'DHL%' }
    });
}
elsif(Test::XTracker::Data->whatami eq 'DC2'){
    $carrier_rs = $schema->resultset('Public::Carrier')->search({
        -or => [
            { name => { like => 'UPS%' } },
            { name => { like => '%Express'} }
        ],
    });
}
my $carriers;
while (my $carrier_row = $carrier_rs->next){
    $carriers->{$carrier_row->id} = $carrier_row->name;
}


my $pids    = Test::XTracker::Data->find_or_create_products({
    channel_id => $channel->{id},
    how_many   => 1,
});

my $pid = $pids->[0]->{pid};
my $rh_items = {
    $pids->[0]{sku} => { price => 100.00, tax => 10, duty => 5 },
};

my $order = Test::XTracker::Data->create_db_order({
    channel_id          => $channel->{id},
    items               => $rh_items,
    shipping_account_id => 3,
});

ok(defined $order);
ok(my $shipment = $order->shipments->first, "Got shipment");
my $now = DateTime->now;
my $now_string  = $now->ymd("") . $now->hms("");
$shipment->update({
    outward_airway_bill => $now_string . int(rand(10_000)),
    return_airway_bill  => $now_string . int(rand(10_000)),
});
$shipment->discard_changes;
ok(
    my $outward_airway_bill = $shipment->outward_airway_bill,
    "Got outward_airway_bill",
);


my $nominated_weekday_date  = "2012-07-02"; # Mon
my $nominated_saturday_date = "2012-07-07"; # Saturday
my $test_cases = [
    {
        description => "Regular",
        setup => {
            nominated_delivery_date => undef,
        },
        expected => {
            nominated_delivery_date             => undef,
            is_saturday_nominated_delivery_date => 0,
        },
    },
    {
        description => "Nominated Weekday",
        setup => {
            nominated_delivery_date => $nominated_weekday_date,
        },
        expected => {
            nominated_delivery_date => XT::Data::DateStamp->from_string(
                $nominated_weekday_date,
            ),
            is_saturday_nominated_delivery_date => 0,
        },
    },
    {
        description => "Nominated Saturday",
        setup => {
            nominated_delivery_date => $nominated_saturday_date,
        },
        expected => {
            nominated_delivery_date => XT::Data::DateStamp->from_string(
                $nominated_saturday_date,
            ),
            is_saturday_nominated_delivery_date => 1,
        },
    },
];
for my $case (@$test_cases) {
    test_prefix($case->{description});
    $shipment->update({
        nominated_delivery_date => $case->{setup}->{nominated_delivery_date},
    });
    $shipment->discard_changes;

    my $params = {
        country    => 'All',
        from_date  => DateTime->now()->subtract( days => 4 )->strftime('%Y-%m-%d %H:%M:%S'),
        to_date    => DateTime->now()->add( days => 1 )->strftime('%Y-%m-%d %H:%M:%S'),
        channel_id => $channel->id,
        carriers   => $carriers,
        carrier_id => 1,
        channels   => get_channels($dbh),
    };
    my $results = outbound_airwaybill_report(
        $dbh,
        $params->{country},
        $params->{from_date},
        $params->{to_date},
        $params->{channel_id},
        $params->{channels},
        $params->{carrier_id},
        $params->{carriers},
    );


    ## Check result
    my $result = $results->{$outward_airway_bill};
    is($result->{carrier_name} , "DHL Express", "Got expected carrier");
    is(
        $result->{nominated_delivery_date},
        $case->{expected}->{nominated_delivery_date},
        "nominated_delivery_date ok",
    );
    is(
        $result->{is_saturday_nominated_delivery_date},
        $case->{expected}->{is_saturday_nominated_delivery_date},
        "is_saturday_nominated_delivery_date ok",
    );


    eq_or_diff(
        [ sort keys %$result ],
        [ sort qw/
                     account_number
                     actual_weight
                     boxes
                     carrier_id
                     carrier_name
                     channel_id
                     country
                     currency_id
                     date
                     dhl_tariff_zone
                     id
                     is_saturday_nominated_delivery_date
                     item_weight
                     nominated_delivery_date
                     num_pieces
                     order_nr
                     outward_airway_bill
                     sales_channel
                     shipping_account_id
                     shipping_charge
                     tariff
                     total_duty
                     total_tax
                     total_value
                     total_weight
                     volumetric_weight
                 /],
        "Got all expected result keys",
    );


    note("*** Test CSV file");
    $mech->get("/Reporting/ShippingReports/AirwaybillReport");
    $mech->submit_form(
        with_fields => {
            carrier_id => 0,
            channel_id => 0,
            country    => "All",
            fromday    => 3,
            frommonth  => 7,
            fromyear   => 2008,
            today      => 4,
            tomonth    => 12,
            toyear     => 2023,
            csv_export => 1,
        },
    );

    note("Test header");
    my $content = $mech->content;
    like(
        $content,
        qr/"Shipment Number","Sales Channel","Carrier","Total Shipment Charge","Shipment Date","Shipment Pieces","Sender Account","Sender Reference","Receiver Country","Actual Weight","DIM Weight","Customs Value","Taxes","Duties","Shipping Charge","Boxes","Nominated Delivery Date","Is Nominated Saturday Delivery"/,
        "Header ok",
    );

    note("Test Airwaybill line");
    my ($shipment_line) = grep { /$outward_airway_bill/ } split(/\n/, $content);
    ok($shipment_line, "Found line for airway bill");
    like($shipment_line, qr/DHL Express/, "Carrier ok");

    if(my $date = $case->{expected}->{nominated_delivery_date}) {
        like($shipment_line, qr/"$date"/, "nominated_delivery_date ok");
    }

    my $is = $case->{expected}->{is_saturday_nominated_delivery_date};
    like($shipment_line, qr/"$is"$/, "is_saturday_nominated_delivery_date present ($is)");
}





done_testing;

