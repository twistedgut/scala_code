#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use DateTime;
use Test::XTracker::LoadTestConfig;
use Data::Dump  qw( pp );
use Test::XT::Prove::Feature::NominatedDay;
use XT::Data::NominatedDay::Shipment;
use XTracker::Constants::FromDB qw/
    :shipment_item_status
    :shipment_status
    :shipment_type
/;


my $schema = Test::XTracker::Data->get_schema;
my $public_shipment_rs = $schema->resultset('Public::Shipment');
my $pid_set = Test::XTracker::Data->get_pid_set({
    nap => 1,
    out => 1,
    mrp => 1,
    jc  => 1,
});

my $now = $schema->db_now;
note "  NOW: ". $now;
my $nom_feature = Test::XT::Prove::Feature::NominatedDay->new();

foreach my $bus (values %{$pid_set}) {
    my $channel = $bus->{channel};

    next if (! $channel->is_enabled);
    my $pids = $bus->{pids};
    my $timezone = $channel->timezone;

    my $before_set = $public_shipment_rs->nominated_to_dispatch_on_day(
        $now
    );
    my $premier_before      = $before_set->premier->count;
    my $non_premier_before  = $before_set->non_premier->count;

    my $before_status = $public_shipment_rs
        ->nominated_day_status_count_for_day($now);

    # this way uses an functional index - should be faster than above method
    my $before_count = $before_set->count;


    # create shipment and set it to today's date
    my $shipment_non_premier = Test::XTracker::Data->create_domestic_order(
        channel => $channel,
        pids => $pids,
    )->shipments->first;
    my $shipment_premier = Test::XTracker::Data->create_domestic_order(
        channel => $channel,
        pids => $pids,
    )->shipments->first;
    $shipment_premier->update({
        shipment_type_id => $SHIPMENT_TYPE__PREMIER
    });

    $nom_feature->set_nominated_fields($shipment_non_premier, {
            # just set it to now - no manipulation needed
            dispatch_time   => { add => { minutes => 1} },
            sla_cutoff_time => { add => { minutes => 1} },
            selection_time  => {  add => {minutes => 1} },
        }, $timezone);
    $nom_feature->set_nominated_fields($shipment_premier, {
            # just set it to now - no manipulation needed
            dispatch_time   => { add => { minutes => 1} },
            sla_cutoff_time => { add => { minutes => 1} },
            selection_time  => {  add => {minutes => 1} },
        }, $timezone);

    note "shipment_id: ". $shipment_non_premier->id;
    note "shipment_id: ". $shipment_premier->id;

    my $after_set = $public_shipment_rs->nominated_to_dispatch_on_day(
        $now
    );

    # functional index
    my $after_count     = $after_set->count;
    my $premier_after   = $after_set->premier->count;


    is ($premier_after - $premier_before, 1,
        "premier count increased after shipment -"
            . " before ($premier_before) - after ($premier_after)");

    my $non_premier_after = $after_set->non_premier->count;

    is ($non_premier_after - $non_premier_before, 1,
        "non-premier count increased after shipment -"
            . " before ($non_premier_before) - after ($non_premier_after)");


    # functional index - should be two.. 1 premier, 1 non-premier
    #$shipment_premier->result_source->schema->storage->debug(1);
    is ($after_count - $before_count, 2,
        "nominated day (functional index method) increased after shipment");

    my $after_status = $public_shipment_rs
        ->nominated_day_status_count_for_day($now);

    test_nominated_day_status_count_for_day($before_status,$after_status);

}



done_testing;


sub test_nominated_day_status_count_for_day {
    my($before,$after) = @_;

    my $b = _array_to_hash($before->{status});
    my $a = _array_to_hash($after->{status});

    is($a->{'New'}->{premier} - $b->{'New'}->{premier}, 1,
        'New status for premier increased');
    is($a->{'New'}->{'non_premier'} - $b->{'New'}->{'non_premier'}, 1,
        'New status non_premier increased');
}

sub _array_to_hash {
    my($array) = @_;
    my $data;

    foreach my $item (@{$array}) {
        $data->{ $item->{label} } = $item;
    }

    return $data;
}
