package Test::NAP::Dispatch;

use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Guard;
use Data::Dump 'pp';

sub startup : Test(startup) {
    my ( $self ) = @_;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{shipment_types} = $self->{schema}->resultset('Public::ShipmentType');
}

sub test_zero_dispatch_lanes : Tests {
    my ( $self ) = @_;

    # no shipment types should have zero dispatch lanes
    my $matching_shipment_types = $self->{shipment_types}
        ->search_rs(
            undef,
            {
                columns  => [qw( me.id me.type )],
                join     => 'link_shipment_type__dispatch_lanes',
                group_by => [qw( me.id me.type )],
                having   => \[ 'count(link_shipment_type__dispatch_lanes.dispatch_lane_id) = ?' => [ dummy_count => 0 ] ],
            }
        );

    is($matching_shipment_types->count, 0, 'no shipment types should have zero dispatch lanes')
        || note('Shipment types with no dispatch lane: '.join(', ', $matching_shipment_types->get_column('me.type')->all));
}

sub test_one_dispatch_lane : Tests {
    my ( $self ) = @_;

    my ($matching_shipment_type) = $self->{shipment_types}
        ->search_rs(
            undef,
            {
                columns  => [qw( me.id me.type )],
                join     => 'link_shipment_type__dispatch_lanes',
                group_by => [qw( me.id me.type )],
                having   => \[ 'count(link_shipment_type__dispatch_lanes.dispatch_lane_id) = ?' => [ dummy_count => 1 ] ],
                rows => 1,
            }
        )->all;

    if ($matching_shipment_type) {
        note "Checking dispatch lanes for shipment type '".$matching_shipment_type->type."'";

        # get dispatch lane id for this shipment type
        my $dispatch_lane_number = $matching_shipment_type->dispatch_lanes->slice(0,0)->single->lane_nr;

        # check lane returned by round robin twice - should match both times
        for (qw( first second )) {
            is $matching_shipment_type->get_lane, $dispatch_lane_number, "$_ call to get_lane should return the only lane number";
        }
    } else {
        # without a single-lane shipment type, we can't test the round robin here
        SKIP: {
            skip 'test single dispatch lane not possible - no suitable shipment type', 2;
        }
    }
}

sub test_multiple_dispatch_lanes : Tests(2) {
    my ( $self ) = @_;

    # find shipment types having multiple dispatch lanes
    my ($matching_shipment_type) = $self->{shipment_types}
        ->search_rs(
            undef,
            {
                columns  => [qw( me.id me.type )],
                join     => 'link_shipment_type__dispatch_lanes',
                group_by => [qw( me.id me.type )],
                having   => \[ 'count(link_shipment_type__dispatch_lanes.dispatch_lane_id) > ?' => [ dummy_count => 1 ] ],
                rows => 1,
            }
        )->all;

    if ($matching_shipment_type) {
        note "Checking dispatch lanes for shipment type '".$matching_shipment_type->type."'";

        # get all dispatch lanes for this shipment type
        my @dispatch_lane_numbers = $matching_shipment_type->dispatch_lanes->get_column('lane_nr')->all;
        note "Dispatch lanes for ".$matching_shipment_type->type.": ".join(', ', sort { $a <=> $b } @dispatch_lane_numbers);
        my %lanes_used = ( map { ($_ => 0) } @dispatch_lane_numbers );

        # call get_lane 2n times where n=number of lanes: we should see all
        # lanes used twice, proving that round robin works
        for (1..@dispatch_lane_numbers*2) {
            my $lane_number = $matching_shipment_type->get_lane;
            note "call $_ returns dispatch lane number $lane_number";
            $lanes_used{$lane_number}++;
        }
        is scalar(grep { $_ == 0 } values %lanes_used), 0, 'all round robin lanes should be used';
        is scalar(grep { $_ == 2 } values %lanes_used), scalar(@dispatch_lane_numbers), 'each round robin dispatch lane should be used twice';
    } else {
        # without a multi-lane shipment type, we can't test the round robin here
        SKIP: {
            skip 'test multiple dispatch lanes not possible - no suitable shipment type', 2;
        }
    }
}

sub test_shipment_type_with_no_lane : Tests {
    my ( $self ) = @_;

    # create new shipment type
    my $st_rs = $self->{schema}->resultset('Public::ShipmentType');
    my $next_st_id = $st_rs->get_column('id')->max + 1; # ugh! patches haven't been using sequence :(
    my ($new_shipment_type) = $st_rs->create({
        id => $next_st_id,
        type => "TestShipmentType$$",
    });
    ok $new_shipment_type, 'should create temporary shipment type';
    my $new_shipment_type_guard = guard {
        note 'clean up temporary shipment type';
        $new_shipment_type->delete;
    };
    is $new_shipment_type->dispatch_lanes->count, 0, 'temporary shipment type should have no dispatch lanes';

    # find the 'unknown' shipment type - our new type should mirror its lane
    # behaviour
    my $unknown_shipment_type = $st_rs->search({
        type => 'Unknown'
    })->slice(0,0)->single;
    my @unknown_lanes = $unknown_shipment_type->dispatch_lanes->get_column('lane_nr')->all;
    note "'Unknown' shipments use lane numbers ".join(',', sort { $a <=> $b } @unknown_lanes);

    # call get_lane on our new shipment type, 2*number_of_dispatch_lanes times
    my %lanes_used;
    for (1..2*@unknown_lanes) {
        my $lane_nr = $new_shipment_type->get_lane;
        note "call $_ returns dispatch lane number $lane_nr";
        $lanes_used{$lane_nr}++;
    }

    # check that all lanes for 'Unknown' shipments have been used
    is_deeply [sort keys %lanes_used], [sort @unknown_lanes], "dispatch lanes used should match those for 'Unknown' shipment type";

    # check that each lane has been used exactly twice
    ok !scalar(grep { $_ != 2 } values %lanes_used), 'each lane should be used exactly twice';
}

sub test_get_dispatch_lane_config : Tests {
    my ( $self ) = @_;

    my $shipment_type_rs = $self->{schema}->resultset('Public::ShipmentType');
    can_ok $shipment_type_rs, 'get_dispatch_lane_config';

    # build expected config
    my $expected_config = {};
    for my $shipment_type ( $shipment_type_rs->all ) {
        # get dispatch lanes for this shipment type
        my @lane_numbers = $shipment_type->dispatch_lanes->get_column('lane_nr')->all;
        # note expected config
        $expected_config->{$shipment_type->id} = {
            type => $shipment_type->type,
            dispatch_lanes => { map { ( $_ => { lane_number => $_ } ) } @lane_numbers },
        };
    }

    ok my $actual_config = $shipment_type_rs->get_dispatch_lane_config, 'should get dispatch lane config';
    is ref($actual_config), 'HASH', 'dispatch lane config should be a hashref';
    is_deeply $actual_config, $expected_config, 'dispatch lane config should match expected config'
        or note 'Expected config: '.pp($expected_config);
}

1;
