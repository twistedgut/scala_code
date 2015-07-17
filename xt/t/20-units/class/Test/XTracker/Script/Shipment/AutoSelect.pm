package Test::XTracker::Script::Shipment::AutoSelect;

use NAP::policy "tt", qw/test class/;

use Data::Dump 'pp';

BEGIN {
    extends 'NAP::Test::Class';
    with qw/Test::Role::WithSchema Test::Role::DBSamples/;
};
use XTracker::Config::Local 'config_var';
use XTracker::Constants::FromDB ':storage_type';
use XTracker::Script::Shipment::AutoSelect;
use Test::XTracker::Data::PackRouteTests;

use Test::XTracker::Artifacts::RAVNI;

sub startup : Tests(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{auto_select} = XTracker::Script::Shipment::AutoSelect->new;

    # Make sure we have a valid pack_lane config
    my $pack_lane_data = Test::XTracker::Data::PackRouteTests->new();
    $pack_lane_data->reset_and_apply_config($pack_lane_data->like_live_packlane_configuration());

}

sub test___get_shipment_ids :Tests() {
    my ($self) = @_;

    # Create a bunch of customer orders and transfer_shipments
    my $shipments = {};
    for (1..3) {
        $shipments->{"c$_"} = $self->test_data->new_order( products => $_ )->{'shipment_object'};
        $shipments->{"c$_"}->update({
            sla_priority                => 5-$_,
            wms_initial_pick_priority   => 5-$_,

            wms_deadline    => DateTime->now()->add( hours => 2-$_ ),
            sla_cutoff      => DateTime->now()->add( hours => 2-$_ ),
        });
    }
    $shipments->{"c2"}->update({ is_prioritised => 1 });

    for(1..2) {
        $shipments->{"s$_"} = $self->db__samples__create_shipment();
        $shipments->{"s$_"}->update({
            sla_priority                => 5-$_,
            wms_initial_pick_priority   => 5-$_,

            wms_deadline    => DateTime->now()->add( hours => 2-$_ ),
            sla_cutoff      => DateTime->now()->add( hours => 2-$_ ),
        });
    }
    $shipments->{"s2"}->update({ is_prioritised => 1 });
    my @ship_ids = map { $_->id } values %$shipments;

    my @selected_ship_ids = $self->{auto_select}->_get_shipment_ids(
        restricted_ids  => \@ship_ids,
        count           => 3,
    );

    # Make sure the prioritised transfer shipment is listed first and then then the two order shipments
    is_deeply(\@selected_ship_ids, [
        $shipments->{'s2'}->id(),
        $shipments->{'c2'}->id(),
        $shipments->{'c3'}->id(),
    ], 'Correct amount of shipments returned in correct order');

}

sub test_invoke : Tests() {
    my $self = shift;

    # For the moment we're only testing this for PRL-enabled
    # configurations
    if ( config_var(qw/PRL rollout_phase/) ) {
        $self->_test_invoke_prl;
    }
    else {
        SKIP: {
            skip 'test_invoke not implemented yet for non-PRL configurations', 1;
            ok 1;
        }
    }
}

sub _test_invoke_prl {
    my $self = shift;

    note "*** Setup";

    # In order to test this... let's create an allocated shipment in the Full
    # PRL and another one in the DMS to guarantee we have some allocations in
    # the system.
    # We basically need to test two parts:
    # - one call that sends pick messages to full prl allocations
    # - the other either sends pick messages to dematic or sets the induction
    #   point

    # Create one flat and one dematic flat product in case we don't have any -
    # so we can guarantee that we have at least one item to pick from both pick
    # scheduler calls
    $self->test_data->new_order(products => [$_]) for map {
        Test::XTracker::Data->create_test_products({ storage_type_id => $_ })
    } $PRODUCT_STORAGE_TYPE__FLAT, $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT;

    my $ps = XTracker::PickScheduler->new;
    my $rs = $self->schema->resultset('SystemConfig::Parameter');

    # Make sure we have capacity to pick a full shipment - this takes the
    # minimum of the following two parameters, so we need to check/set them
    # both
    my $required_staging_area_size = $self->_size_to_guarantee_spare_places(
        $ps->staging_area_size, $ps->staging_area_capacity
    );

    # Make sure we have capacity to pick a dematic or induct an allocation from
    # the staging area
    my $required_packing_pool_size = $self->_size_to_guarantee_spare_places(
        $ps->packing_pool_size, $ps->pack_lane_spare_places
    );

    # Set our sizes
    ok( $rs->search({name => $_->[0]})->update({value => $_->[1]}),
        "updated $_->[0] to $_->[1]"
    ) for ['staging_area_size', $required_staging_area_size],
          ['packing_pool_size', $required_packing_pool_size];

    # Start a message monitor to check the pick scheduler did its stuff
    my $xt_to_prl = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');


    note "*** Run";
    $self->{auto_select}->invoke(auto_select_shipments => 1);


    note "*** Test";
    my @files = $xt_to_prl->new_files;
    # Let's check that pick_full_shipments was called by checking that a
    # message was sent
    ok((grep { $_->path =~ m{dc\d+/prl_full$} } @files),
        'sent pick message for full prl'
    ) or diag pp \@files;

    # ... and let's check that set_induction_capacity_and_release_dms_only was
    # called. Depending on the order in which the allocations are set (remember
    # we only freed up one space on the pack lane), we need to check whether
    # the allocation placed on it comes from the staging area or Dematic. So:

    # - if it came from Dematic we'd expect to see a pick message to Dematic
    if ( grep { $_->path =~ m{dc\d+/prl_dematic$} } @files ) {
        pass 'sent pick message for dematic';
    }
    # - if it came from the staging area we'd expect to see the induction
    # capacity > 0
    # NOTE: The induction capacity *is* being dropped at some point (when we
    # start to use GOHs I think). When that happens this condition may need to
    # be rewritten or revisited anyway, otherwise it could be the cause of
    # random test failures.
    elsif ( $self->schema->resultset('Public::RuntimeProperty')->find_by_name('induction_capacity') > 0 ) {
        pass 'induction capacity updated';
    }
    # - else we have a failure
    else {
        fail join qq{\n},
            'no pick messages sent to Dematic nor was the induction capacity updated.',
            'The induction capacity stayed at 0',
            'and the pick messages sent were: ' . pp \@files;
    }
}

# When passed the total size and curent free size (and optionally a required
# free size, defaults to 1), this sub will return the total size needed to
# provide the given number of spare places
sub _size_to_guarantee_spare_places {
    my ( $self, $total_size, $current_free_size, $required_free_size ) = @_;
    $required_free_size //= 1;
    return $current_free_size > 0 ? $total_size
        : $total_size + ($required_free_size-$current_free_size);
}
