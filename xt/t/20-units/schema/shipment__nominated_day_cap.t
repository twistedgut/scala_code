#!perl

use NAP::policy "tt", 'test';

use Data::Dump  qw( pp );

use Test::More::Prefix qw/test_prefix/;
use Test::XTracker::LoadTestConfig;
use Test::XT::Prove::Feature::NominatedDay;
use XT::Data::NominatedDay::Shipment;
use XTracker::Config::Local qw/config_var/;

my $schema = Test::XTracker::Data->get_schema;

my $channel = Test::XTracker::Data->channel_for_nap;
# We skip all tests if NAP doesn't support nominated shipments - currently this
# is the case just for DC3
plan skip_all => 'Channel has no shipping charges, skipping test'
    unless $channel->has_nominated_day_shipping_charges;

my $public_shipment_rs = $schema->resultset('Public::Shipment');

# channel is irrelevant as the cap is for the distribution centre
my $pids = Test::XTracker::Data->grab_products({channel_id => $channel->id});

my $now = $schema->db_now;
my $nom_feature = Test::XT::Prove::Feature::NominatedDay->new();

    my $timezone = $now->time_zone->name;
    $now->set_time_zone($timezone);
    note "  NOW: ". $now;

    my $current_count = $public_shipment_rs->nominated_to_dispatch_on_day(
        $now
    )->count;

    my $check_daily_cap_params = {
        max_daily_shipment_count => $current_count + 1,
        alert_every_n => 2,
    };
    note "current count: $current_count";
    note "params: ". pp($check_daily_cap_params);

    # to keep track of the count before and after a call to a method we are
    # expecting to increment it
    my($before_count,$after_count) = ($current_count,
        $public_shipment_rs->nominated_to_dispatch_on_day($now)
            ->count
    );


    # 1: not reached cap - no need to test count as first call doesn't do
    # anything
    test_prefix("1: not reached cap");
    test_check_daily_cap_output(
        $check_daily_cap_params,
        $after_count,
        XT::Data::NominatedDay::Shipment->new($check_daily_cap_params)
            ->check_daily_cap($now),
    );

    $before_count = $after_count;


    # 2: reached cap
    test_prefix("2: reached cap");
    create_nominated_shipment({
        channel => $channel,
        pids => $pids,
        timezone => $timezone,
    });

    $after_count = $public_shipment_rs->nominated_to_dispatch_on_day($now)
        ->count;

    test_check_daily_cap_output(
        $check_daily_cap_params,
        $public_shipment_rs->nominated_to_dispatch_on_day($now)->count,
        XT::Data::NominatedDay::Shipment->new($check_daily_cap_params)
            ->check_daily_cap($now),
    );

    $before_count = test_nominated_count_change(
        $before_count,$after_count
    );


    # 3: exceed cap by one
    test_prefix("3: exceed cap by one");
    create_nominated_shipment({
        channel => $channel,
        pids => $pids,
        timezone => $timezone,
    });
#    change_to_nominated_shipment({
#        channel => $channel,
#        pids => $pids,
#        timezone => $timezone,
#    });

    $after_count = $public_shipment_rs->nominated_to_dispatch_on_day($now)
        ->count;

    test_check_daily_cap_output(
        $check_daily_cap_params,
        $public_shipment_rs->nominated_to_dispatch_on_day($now)->count,
        XT::Data::NominatedDay::Shipment->new($check_daily_cap_params)
            ->check_daily_cap($now),
    );

    $before_count = test_nominated_count_change(
        $before_count,$after_count
    );


    # 4: exceed cap by two and trigger alert
    test_prefix("4: exceed cap by two and trigger alert");
    create_nominated_shipment({
        channel => $channel,
        pids => $pids,
        timezone => $timezone,
    });

    $after_count = $public_shipment_rs->nominated_to_dispatch_on_day($now)
        ->count;

    test_check_daily_cap_output(
        $check_daily_cap_params,
        $public_shipment_rs->nominated_to_dispatch_on_day($now)->count,
        XT::Data::NominatedDay::Shipment->new($check_daily_cap_params)
            ->check_daily_cap($now),
    );

    $before_count = test_nominated_count_change(
        $before_count,$after_count
    );


done_testing;



sub test_nominated_count_change {
    my($before_count,$after_count) = @_;

    is($before_count + 1,$after_count,'Nominated day count incremented');

    return $after_count;
}

sub test_check_daily_cap_output {
    my($params,$current_count,$output) = @_;
    my $cap = $params->{max_daily_shipment_count} || undef;
    my $every_n = $params->{alert_every_n} || undef;
    die "daily cap isn't set" if (!defined $cap);
    die "alert every n isn't set" if (!defined $every_n);
    note "test_params: ". pp($params);

    my $offset = $current_count - $cap;
    if ($offset == 0 || $offset % $every_n == 0) {
        note "testing: email expected";
        like($output,qr/Cap: $cap/,
            'email - contains cap value'
        ) or pp($output);
        like($output,qr/Number of Shipments: $current_count/,
            'email - contains current count'
        ) or pp($output);
    } else {
        note "testing: no email expected";
        is($output, undef, 'No content - no warning email expected');
    }
}

sub create_nominated_shipment {
    my($args) = @_;

    # create shipment and set it to today's date
    my $shipment = Test::XTracker::Data->create_domestic_order(
        channel => $args->{channel},
        pids => $args->{pids},
    )->shipments->first;

    $nom_feature->set_nominated_fields($shipment, {
            # just set it to now - no manipulation needed
            dispatch_time   => { add => { minutes => 1} },
            sla_cutoff_time => { add => { minutes => 1} },
            selection_time  => {  add => {minutes => 1} },
        }, $args->{timezone}, $now);

    note "shipment_id: ". $shipment->id;
    note "nominated shipment count: ".
        $public_shipment_rs->nominated_to_dispatch_on_day(
            $now
        )->count;
    return $shipment;
}
