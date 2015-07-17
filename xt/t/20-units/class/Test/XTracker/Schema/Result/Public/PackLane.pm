package Test::XTracker::Schema::Result::Public::PackLane;
use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
    with $_ for qw{Test::Role::WithSchema};
};

use Test::XTracker::RunCondition prl_phase => 'prl';

our $pt; # Class to call ->premier, etc. on
BEGIN { $pt = "Test::XTracker::Data::PackRouteTests" }

use Test::XTracker::Data::PackRouteTests;

use XTracker::Constants::FromDB qw<
    :pack_lane_attribute
>;

sub test__attributes :Tests {
    my ($self) = @_;

    my $schema = $self->schema();
    my $packlane_test_data = Test::XTracker::Data::PackRouteTests->new();

    my $test_packlane = $packlane_test_data->reset_and_apply_config()->first();
    $test_packlane->search_related('pack_lanes_has_attributes')->delete();

    note("We've created a test packlane for these tests, with no initial attributes");
    is_deeply($test_packlane->get_attribute_ids(), {},
        'Since we have no attributes, get_attribute_ids() returns an empty hash');

    note('Call add_attribute() on the test packlane to assign "Single Tote" and "Premier" attributes');
    $test_packlane->add_attribute($PACK_LANE_ATTRIBUTE__PREMIER);
    $test_packlane->add_attribute($PACK_LANE_ATTRIBUTE__SINGLE);

    is_deeply($test_packlane->get_attribute_ids(), {
        $PACK_LANE_ATTRIBUTE__SINGLE => 1,
        $PACK_LANE_ATTRIBUTE__PREMIER => 1,
    }, 'get_attribute_ids() now returns a hash with the "Single-Tote" and "Premier"');

    note('Remove single attribute and call add_attribute() on the test packlane add "Multi-Tote"');
    $test_packlane->remove_attribute($PACK_LANE_ATTRIBUTE__SINGLE);
    $test_packlane->add_attribute($PACK_LANE_ATTRIBUTE__MULTITOTE);

    is_deeply($test_packlane->get_attribute_ids(), {
        $PACK_LANE_ATTRIBUTE__MULTITOTE => 1,
        $PACK_LANE_ATTRIBUTE__PREMIER => 1,
    }, 'get_attribute_ids() now returns a hash with only "Multi-Tote"');

}

sub test__get_containers_on_packlane_count :Tests {
    my ($self) = @_;

    my $schema = $self->schema();
    my $packlane_test_data = Test::XTracker::Data::PackRouteTests->new();

    my $test_packlane = $packlane_test_data->reset_and_apply_config()->first();

    is($test_packlane->get_containers_on_packlane_count(), 0,
       'Empty packlane reports no containers');

    $test_packlane->update({
        'container_count' => 1,
    });

    is($test_packlane->get_containers_on_packlane_count(), 1,
       'After updating the "container_count" column, this value is returned'
       . ' (as it is higher than the amount of containers that report'
       . ' themselves arrived) ');

    note('Now we will add a few containers, initially in unarrived state');
    $packlane_test_data->create_container('M1', $pt->standard, 1, 1)->update({
        pack_lane_id    => $test_packlane->id(),
        has_arrived     => 0,
    });
    $packlane_test_data->create_container('M2', $pt->standard, 1, 1)->update({
        pack_lane_id    => $test_packlane->id(),
        has_arrived     => 0,
    });

    is($test_packlane->get_containers_en_route_count(), 2,
       'two containers en route to pack lane');

    is($test_packlane->get_containers_on_packlane_count(), 1,
       'container count is still 1 as the containers are both marked as not arrived');

    foreach my $container ($test_packlane->containers) {
        $container->mark_has_arrived_at_pack_lane;
    }

    is($test_packlane->get_containers_on_packlane_count(), 2,
       'container count is now 2 as there are more arrived containers than in the'
       . ' "container_count"');

    is($test_packlane->get_containers_en_route_count(), 0,
       'no containers en route to pack lane');
}

1;
