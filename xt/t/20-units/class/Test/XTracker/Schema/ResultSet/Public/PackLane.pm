package Test::XTracker::Schema::ResultSet::Public::PackLane;
use NAP::policy "tt", qw/test class/;

use Test::XTracker::RunCondition prl_phase => 'prl';
use Test::Exception;

BEGIN {
    extends 'NAP::Test::Class';
    with qw/Test::Role::WithSchema/;
};

use XTracker::Constants::FromDB qw<
    :pack_lane_attribute
>;

use Test::XTracker::Data::PackRouteTests;

sub startup :Tests(startup) {
    my $self = shift;

    $self->SUPER::startup;
    my $plt = Test::XTracker::Data::PackRouteTests->new;

    $plt->reset_and_apply_config($plt->like_live_packlane_configuration());

}

sub test__with_or_without_attributes :Tests {
    my ($self) = @_;

    my $schema = $self->schema();
    $schema->txn_do(sub {

        $self->_create_packlane_test_data();

        note('So if we ask for all the Premier Single-tote lanes...');
        my @premier_single_tote_lanes = $schema->resultset('Public::PackLane')->with_attributes([
            $PACK_LANE_ATTRIBUTE__SINGLE,
            $PACK_LANE_ATTRIBUTE__PREMIER
        ]);
        is(@premier_single_tote_lanes, 2, 'We get 2 back');

        my @pack_lane_ids = map { $_->pack_lane_id(), } @premier_single_tote_lanes;
        is_deeply(\@pack_lane_ids, [1, 3], 'And they have the pack_lane_ids we expect');

        note('And if we ask for all the Non-Premier Multi-tote lanes...');
        my @non_premier_multi_tote_lanes = $schema->resultset('Public::PackLane')->without_attributes([
            $PACK_LANE_ATTRIBUTE__PREMIER,
        ])->with_attributes([
            $PACK_LANE_ATTRIBUTE__MULTITOTE,
        ]);
        is(@non_premier_multi_tote_lanes, 4, 'We get 4 back (including the sample and default lanes)');

        @pack_lane_ids = map { $_->pack_lane_id(), } @non_premier_multi_tote_lanes;
        is_deeply(\@pack_lane_ids, [4, 6, 7, 8], 'And they have the pack_lane_ids we expect');

        $schema->txn_rollback();
    });
}

sub test__update_packlanes :Tests {
    my ($self) = @_;

    my $schema = $self->schema();

    my @premier_single_tote_pack_lanes;
    $schema->txn_do(sub {

        $self->_create_packlane_test_data();

        # Find a packlane that is enabled and make sure we can turn it off. Also get one that is turned on and set it to turned
        # on to make sure the code doesn't throw a wobbler when we do something like that
        my $active_packlanes = $schema->resultset('Public::PackLane')->with_attributes([
            $PACK_LANE_ATTRIBUTE__SINGLE,
            $PACK_LANE_ATTRIBUTE__STANDARD
        ])->search({
            active  => 1,
        });

        die 'Can not continue with tests unless we have at least two single-tote, active, standard pack lanes'
            unless $active_packlanes->count() >= 2;

        my $packlane_to_disable = $active_packlanes->next();
        my $packlane_to_disable_id = $packlane_to_disable->pack_lane_id();
        my $packlane_to_leave_on = $active_packlanes->next();
        my $packlane_to_leave_on_id = $packlane_to_leave_on->pack_lane_id();

        lives_ok { $schema->resultset('Public::PackLane')->update_packlanes({
            $packlane_to_disable->pack_lane_id() => {
                active => 0,
            },
            $packlane_to_leave_on->pack_lane_id() => {
                active => 1,
            }
        }) } 'Attempt to disable an active packlane (id: ' . $packlane_to_disable_id
            . ') and set another active when it already is (id: ' . $packlane_to_leave_on_id . ') lives';

        $packlane_to_disable->discard_changes();
        is($packlane_to_disable->active(), 0, "... now packlane with id: $packlane_to_disable_id is disabled");

        $packlane_to_leave_on->discard_changes();
        is($packlane_to_leave_on->active(), 1, "... and packlane with id: $packlane_to_leave_on_id is still enabled");

        $schema->txn_rollback();
    });

    # Test single-tote premier lanes
    $self->_test_premier_flag_for_type($PACK_LANE_ATTRIBUTE__SINGLE);

    # Test multi-tote premier lanes
    $self->_test_premier_flag_for_type($PACK_LANE_ATTRIBUTE__MULTITOTE);
}

sub _test_premier_flag_for_type {
    my ($self, $type) = @_;

    my $schema = $self->schema();
    my $type_obj = $schema->resultset('Public::PackLaneAttribute')->find({ pack_lane_attribute_id => $type });
    my $type_name = $type_obj->name();
    note("Testing packlane type: '$type_name'");
    my @premier_pack_lanes;
    $schema->txn_do(sub {
        # Find all the, premier lanes and attempt to turn them all off (should fail)
        @premier_pack_lanes = $schema->resultset('Public::PackLane')->with_attributes([
            $type,
            $PACK_LANE_ATTRIBUTE__PREMIER,
        ]);
        die "No premier $type_name packlanes in db. This should not be possible" unless @premier_pack_lanes;

        dies_ok { $schema->resultset('Public::PackLane')->update_packlanes({
            map { $_->pack_lane_id() => { is_premier => 0 } } @premier_pack_lanes
        }) } "An attempt to \'de-premier\' all the premier $type_name packlanes dies (at least one must always exist)";
        isa_ok($@, 'NAP::XT::Exception::InvalidPackLaneConfig', '... for the right reason, exception');
        if($type == $PACK_LANE_ATTRIBUTE__SINGLE) {
            is($@->has_no_single_tote_premier(), 1, '... with the \'no_single_tote_premier\' flag set true');
        } elsif($type == $PACK_LANE_ATTRIBUTE__MULTITOTE) {
            is($@->has_no_multi_tote_premier(), 1, '... with the \'no_multi_tote_premier\' flag set true');
        }

        # Need to explicity rollback, since the one inside update_packlanes is now nested and therefore won't have any effect
        $schema->txn_rollback();
    });

    $schema->txn_do(sub {

        # Want to make sure that we can turn off the premier flag on a packlane when there is at least one other
        my $other_premier_pack_lane;
        if(@premier_pack_lanes == 1) {
            # Only got 1! So we'll change another packlane to be premier.
            $other_premier_pack_lane = $schema->resultset('Public::PackLane')->with_attributes([
                $type,
            ])->without_attributes([
                $PACK_LANE_ATTRIBUTE__PREMIER,
            ])->first();
            die 'Could not find a non-premier packlane' unless $other_premier_pack_lane;
            $other_premier_pack_lane->add_attribute($PACK_LANE_ATTRIBUTE__PREMIER);
        } else {
            # Got a bunch of existing ones
            $other_premier_pack_lane = pop @premier_pack_lanes;
        }

        lives_ok{ $schema->resultset('Public::PackLane')->update_packlanes({
            $other_premier_pack_lane->pack_lane_id() => {
                is_premier => 0,
                is_standard => 1,
            },
        }) } "Attempt to 'de-premier' a premier $type_name packlane when there is at least one other lives";

        my $attribute_ids = $other_premier_pack_lane->get_attribute_ids();
        ok(!$attribute_ids->{$PACK_LANE_ATTRIBUTE__PREMIER}, 'packlane no longer has the "premier" attribute');
        ok($attribute_ids->{$PACK_LANE_ATTRIBUTE__STANDARD}, 'packlane now has the "standard" attribute');

        # All done :)
        $schema->txn_rollback();
    });
}

sub test__get_remaining_capacity :Tests {
    my ($self) = @_;

    my $schema = $self->schema();
    $schema->txn_do(sub {

        $self->_create_packlane_test_data();

        my $TOTAL_CAPACITY = 42;

        is($schema->resultset('Public::PackLane')->get_total_capacity(), $TOTAL_CAPACITY,
           'Total capacity is as expected');

        is($schema->resultset('Public::PackLane')->get_remaining_capacity(), $TOTAL_CAPACITY,
            'get_remaining_capacity returns same as total capacity when they are completely empty');

        note('Add two containers that have not arrived at their packlane yet');
        my $pack_lane_rs = $schema->resultset('Public::PackLane')->with_attributes([
            $PACK_LANE_ATTRIBUTE__STANDARD,
        ]);
        my $packlane1 = $pack_lane_rs->next();
        $packlane1->create_related('containers', {
            id          => 'notarrived',
            has_arrived => 0,
        });
        my $packlane2 = $pack_lane_rs->next();
        $packlane2->create_related('containers', {
            id          => 'notarrived2',
            has_arrived => 0,
        });

        is($schema->resultset('Public::PackLane')->get_remaining_capacity(), ($TOTAL_CAPACITY - 2),
            'get_remaining_capacity now returns two less');

        note('Now add 3 containers that HAVE arrived');

        $packlane1->create_related('containers', {
            id          => 'arrived' . $_,
            has_arrived => 1,
        }) for (1 .. 3);

        is($schema->resultset('Public::PackLane')->get_remaining_capacity(), ($TOTAL_CAPACITY - 5),
            'get_remaining_capacity now returns 2 less for the unarrived, and a further 3 less for arrived');

        note('Update a packlane so that its container count is 5 (greater than the arrived count)');
        $packlane1->update({ container_count => 5 });

        is($schema->resultset('Public::PackLane')->get_remaining_capacity(), ($TOTAL_CAPACITY - 7),
            'get_remaining_capacity now returns 2 less for the unarrived, '
            . ' and a further 5 for the container_count '
            . '(arrived count is ignored as it is less than container_count)');

        # All done :)
        $schema->txn_rollback();
    });
}

sub test___select_pack_lane :Tests {
    my ($self) = @_;

    my $schema = $self->schema();
    $schema->txn_do(sub {
        $self->_create_packlane_test_data();

        # Since we have just created these packlanes, we know they are empty, so the one
        # with the highest remaining capacity will be the one with the highest total
        # capacity
        my $packlane_with_highest_capacity = $schema->resultset('Public::PackLane')->search({
            active => 1,
        }, {
            order_by => { -desc => 'capacity' },
            rows => 1,
        })->single();

        my $selected_packlane = $schema->resultset('Public::PackLane')->select_pack_lane();
        is($selected_packlane->id(), $packlane_with_highest_capacity->id(),
            '_select_pack_lane_with_most_remaining_capacity() has returned the correct packlane');

        $schema->resultset('Public::PackLane')->search()->update({
            active => 0,
        });

        my $default_packlane = $schema->resultset('Public::PackLane')->select_pack_lane();
        my $default_packlane_attributes = $default_packlane->get_attribute_ids();
        ok($default_packlane_attributes->{$PACK_LANE_ATTRIBUTE__DEFAULT},
            'When there are no active packlanes, it returns a pack lane with the '
            . '"default" attribute (regardless of that lanes active status)');

        $schema->txn_rollback();
    });
}

sub _create_packlane_test_data {
    my ($self) = @_;

    my $schema = $self->schema();

    note("Delete the current packlane data and create some others so we know exactly what we're dealing with");
    $schema->resultset('Public::PackLaneHasAttribute')->delete();
    $schema->resultset('Public::PackLane')->delete();

    note('Make 6 normal pack lanes and 2 special ones...');
    my @lanes;
    push @lanes, {
        pack_lane_id    => $_,
        human_name      => "Pack Lane $_",
        internal_name   => "INT.$_",
        capacity        => (10-$_),
        active          => (($_ < 8) ? 1 : 0), #
    } for(1..8);
    $schema->resultset('Public::PackLane')->populate(\@lanes);

    note('Half single, half multi...');
    my @attributes;
    push @attributes, {
        pack_lane_id    => $_,
        pack_lane_attribute_id => ($_%2 ? $PACK_LANE_ATTRIBUTE__SINGLE : $PACK_LANE_ATTRIBUTE__MULTITOTE)
    } for(1..8);
    note('And 2 multi premiers and a single premier');
    push @attributes, {
        pack_lane_id    => $_,
        pack_lane_attribute_id => $PACK_LANE_ATTRIBUTE__PREMIER,
    } for(1..3);
    push @attributes, {
        pack_lane_id    => $_,
        pack_lane_attribute_id => $PACK_LANE_ATTRIBUTE__STANDARD,
    } for(4..8);

    note('Lane 7 is the sample lane and does single and multi');
    push @attributes, {
        pack_lane_id    => 7,
        pack_lane_attribute_id => $PACK_LANE_ATTRIBUTE__SAMPLE,
    };
    push @attributes, {
        pack_lane_id    => 7,
        pack_lane_attribute_id => $PACK_LANE_ATTRIBUTE__MULTITOTE,
    };

    note('Lane 8 is the default lane');
    push @attributes, {
        pack_lane_id    => 8,
        pack_lane_attribute_id => $PACK_LANE_ATTRIBUTE__DEFAULT,
    };

    $schema->resultset('Public::PackLaneHasAttribute')->populate(\@attributes);
}

sub test__container_count_sum : Tests() {
    my $self = shift;

    my $pack_lane_rs = $self->schema->resultset('Public::PackLane');
    my $count = $pack_lane_rs->count();
    $pack_lane_rs->update({ container_count => 3 });
    my $expected_sum = $count * 3;

    is(
        $pack_lane_rs->container_count_sum,
        $expected_sum,
        "container_count_sum matches sums all lanes",
    );

}
