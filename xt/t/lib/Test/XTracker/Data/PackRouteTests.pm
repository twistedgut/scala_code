package Test::XTracker::Data::PackRouteTests;

use NAP::policy "tt", 'test', 'class';
BEGIN { with 'XTracker::Role::WithSchema' };

use Test::XTracker::Data;

use XTracker::Constants::FromDB qw(
    :container_status
    :shipment_type
    :shipment_class
    :pack_lane_attribute
);

sub standard   { 0 } # not used
sub premier    { 1 }
sub samples    { 2 }
sub press      { 3 }
sub trans_ship { 4 }

sub like_live_packlane_configuration {
    return [ {
            pack_lane_id => 1,
            human_name => 'pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP02',
            capacity => 14,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__SINGLE ]
        }, {
            pack_lane_id => 2,
            human_name => 'pack_lane_2',
            internal_name => 'DA.PO01.0000.CCTA01NP06',
            capacity => 23,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
        }, {
            pack_lane_id => 3,
            human_name => 'pack_lane_3',
            internal_name => 'DA.PO01.0000.CCTA01NP09',
            capacity => 23,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
        }, {
            pack_lane_id => 4,
            human_name => 'pack_lane_4',
            internal_name => 'DA.PO01.0000.CCTA01NP12',
            capacity => 23,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
        }, {
            pack_lane_id => 5,
            human_name => 'pack_lane_5',
            internal_name => 'DA.PO01.0000.CCTA01NP15',
            capacity => 14,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
        }, {
            pack_lane_id => 6,
            human_name => 'multi_tote_pack_lane_1',
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__PREMIER, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 7,
            human_name => 'multi_tote_pack_lane_2',
            internal_name => 'DA.PO01.0000.CCTA01NP05',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 8,
            human_name => 'multi_tote_pack_lane_3',
            internal_name => 'DA.PO01.0000.CCTA01NP07',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 9,
            human_name => 'multi_tote_pack_lane_4',
            internal_name => 'DA.PO01.0000.CCTA01NP08',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 10,
            human_name => 'multi_tote_pack_lane_5',
            internal_name => 'DA.PO01.0000.CCTA01NP10',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 11,
            human_name => 'multi_tote_pack_lane_6',
            internal_name => 'DA.PO01.0000.CCTA01NP11',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 12,
            human_name => 'multi_tote_pack_lane_7',
            internal_name => 'DA.PO01.0000.CCTA01NP13',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 13,
            human_name => 'multi_tote_pack_lane_8',
            internal_name => 'DA.PO01.0000.CCTA01NP14',
            capacity => 7,
            active => 1,
            attributes => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }, {
            pack_lane_id => 14,
            human_name => 'seasonal_line',
            internal_name => 'DA.PO01.0000.CCTA01NP16',
            capacity => 12,
            active => 1,
            attributes => [
                $PACK_LANE_ATTRIBUTE__SAMPLE,
                $PACK_LANE_ATTRIBUTE__SINGLE,
                $PACK_LANE_ATTRIBUTE__MULTITOTE
            ]
        }, {
            pack_lane_id => 15,
            human_name => 'packing_no_read',
            internal_name => 'DA.PO01.0000.CCTA01NP04',
            capacity => 7,
            active => 0,
            attributes => [
                $PACK_LANE_ATTRIBUTE__DEFAULT,
                $PACK_LANE_ATTRIBUTE__SINGLE,
                $PACK_LANE_ATTRIBUTE__MULTITOTE
            ]
        }
    ];
}

sub reset_and_apply_config {
    my ($self, $config) = @_;

    $config //= $self->like_live_packlane_configuration();

    note("Resetting status and applying new configuration");

    $self->schema->resultset('Public::ShipmentItem')->search({
        container_id => { '!=' => undef }
    })->update({ container_id => undef });

    # delete all the pack lane configs and containers
    # and prepare for testing

    $self->schema->resultset('Public::Container')->update({
        pack_lane_id => undef,
        routed_at    => undef,
        arrived_at   => undef,
        has_arrived  => undef
    });

    $self->reapply_config($config);
}

sub reapply_config {
    my ($self, $config) = @_;

    $self->schema->resultset('Public::Container')->update({
        pack_lane_id => undef,
    });
    $self->schema->resultset('Public::PackLaneHasAttribute')->delete;
    $self->schema->resultset('Public::PackLane')->delete;

    # now lets setup our new config environment...

    foreach my $packlane (@$config) {
        my $new_packlane = {
            pack_lane_id  => $packlane->{'pack_lane_id'},
            human_name    => $packlane->{'human_name'},
            internal_name => $packlane->{'internal_name'},
            capacity      => $packlane->{'capacity'},
            active        => $packlane->{'active'}
        };

        my $pack_lane = $self->schema->resultset('Public::PackLane')->create($new_packlane);
        $pack_lane->discard_changes;

        foreach my $attr_id (@{ $packlane->{'attributes'} }) {
            $self->schema->resultset('Public::PackLaneHasAttribute')->create({
                pack_lane_id => $pack_lane->pack_lane_id,
                pack_lane_attribute_id => $attr_id
            });
        }

    }

    my $resultset = $self->schema->resultset('Public::PackLane')->search();
    return $resultset;
}

sub create_container {
    my ($self, $container_id, $type, $container_number, $total_containers, $parent_id) = @_;

    my $premier = $self->premier;
    my $shipment_type_id = (
        $type == $premier
            ? $SHIPMENT_TYPE__PREMIER
            : $SHIPMENT_TYPE__UNKNOWN
    );
    my $samples = $self->samples;
    my $shipment_class_id = (
        $type == $samples
            ? $SHIPMENT_CLASS__SAMPLE
            : $SHIPMENT_CLASS__STANDARD
    );
    $shipment_class_id = $SHIPMENT_CLASS__PRESS if ($type == $self->press);
    $shipment_class_id = $SHIPMENT_CLASS__TRANSFER_SHIPMENT if ($type == $self->trans_ship);

    my $new_container = $self->schema->resultset('Public::Container')->find_or_create({ id => $container_id });
    $new_container->discard_changes;

    $new_container->update({
        status_id => $PUBLIC_CONTAINER_STATUS__AVAILABLE
    });

    if ($container_number == 1) {

        # create shipment
        my $shipment = Test::XTracker::Data->create_shipment({
            shipment_type_id => $shipment_type_id,
            shipment_class_id => $shipment_class_id
        });

        # Use any old product variant
        my ($channel, $product_data) = Test::XTracker::Data->grab_products({ how_many => 1 });
        my $variant = $product_data->[0]->{variant};

        #note("using variant in the shipment (variant=". $variant->id . ")");

        my $shipment_item = Test::XTracker::Data->create_shipment_item({
            shipment_id => $shipment->id,
            variant_id => $variant->id
        });

        $shipment_item->discard_changes;

        $new_container->add_picked_item({
            dont_validate => 1,
            shipment_item => $shipment_item
        });

        # if it's a multitote, create the other shipment items now
        my $containers_made = 1;

        while ($containers_made < $total_containers) {

            Test::XTracker::Data->create_shipment_item({
                shipment_id => $shipment->id,
                variant_id => $variant->id
            });

            $containers_made++;
        }

    } else {
        # this a subsequent container in a multi tote container.
        # the shipment items have already been created so find
        # one and add it to our new container

        my $parent_container = $self->schema->resultset('Public::Container')->find($parent_id);

        my $next_shipment_item = $self->schema->resultset('Public::ShipmentItem')->search({
            shipment_id => { -in => $parent_container->shipment_ids },
            container_id => undef,
        }, {
            rows => 1
        })->single;

        $new_container->add_picked_item({
            dont_validate => 1,
            shipment_item => $next_shipment_item
        });

    }

    return $new_container;
}

sub _get_container {
    my ($self, $container_id) = @_;

    return $self->schema->resultset('Public::Container')->find($container_id);
}

sub allocate_container {
    my ($self, $container_id) = @_;

    my $container = $self->_get_container($container_id);
    my $result = $container->choose_packlane();
    return $result;
}

sub allocate_container_and_test {
    my ($self, $container_id, $expected_lane, $test_description) = @_;

    my $container = $self->_get_container($container_id);
    my $result = $container->choose_packlane();

    is($result->human_name, $expected_lane, $test_description);
}

sub container_allocation_logged {
    my ($self, $container_id, $expected_lane, $test_description) = @_;

    my $container = $self->schema->resultset('Public::Container')->find($container_id);

    is($container->pack_lane->human_name, $expected_lane, $test_description);

}

sub check_lane_capacity {
    my ($self, $lane, $expected_capacity, $test_description) = @_;

    my $lane_obj = $self->schema->resultset('Public::PackLane')->search({
        human_name => $lane
    })->single;

    if (!defined($lane_obj)) {
        ok(0, "Cannot check lane capacity for $lane. Lane not found!");
        return;
    }

    is($lane_obj->get_available_capacity, $expected_capacity, $test_description);

}

sub get_lane_available_capacity {
    my ($self, $lane) = @_;

    my $lane_obj = $self->schema->resultset('Public::PackLane')->search({
        human_name => $lane
    })->single;

    if (!defined($lane_obj)) {
        ok(0, "Cannot check lane capacity for $lane. Lane not found!");
        return;
    }

    return $lane_obj->get_available_capacity();
}

sub check_total_remaining_capacity {
    my ($self, $expected_total_capacity, $test_description) = @_;

    my @all_pack_lanes = $self->schema->resultset('Public::PackLane')->search({
        active => 1
    });

    my $sum = 0;
    foreach my $pl (@all_pack_lanes) {
        $sum += $pl->get_available_capacity();
    }

    is($sum, $expected_total_capacity, $test_description);
}

sub process_item {
    my ($self, $container_id) = @_;

    # remove it from pack lane..
    my $container = $self->schema->resultset('Public::Container')->find($container_id);
    my $pack_lane = $self->schema->resultset('Public::PackLane')->find($container->pack_lane_id);

    $container->update({
        pack_lane_id => undef
    });

    $pack_lane->incr_capacity;
}

sub check_unprocessed_item_count {
    my ($self, $expected_count, $test_description) = @_;

    my $result = $self->schema->resultset('Public::Container')->search({
        pack_lane_id => { '!=' => undef }
    })->count;

    is($result, $expected_count, $test_description);
}

sub deactivate_pack_lane {
    my ($self, $pack_lane) = @_;

    $self->schema->resultset('Public::PackLane')->search({
        human_name => $pack_lane
    })->update({
        active => 0
    });
}

sub reactivate_pack_lane {
    my ($self, $pack_lane) = @_;

    $self->schema->resultset('Public::PackLane')->search({
        human_name => $pack_lane
    })->update({
        active => 1
    });
}

sub mock_incoming_lane_status_message {
    my ($self, $pack_lane, $container_count) = @_;

    $self->schema->resultset('Public::PackLane')->search({
        human_name => $pack_lane
    })->update({
        container_count => $container_count
    });
}

sub mock_container_arrived {
    my ($self, $container_id) = @_;

    my $container = $self->schema->resultset('Public::Container')->find($container_id);

    $container->update({
        has_arrived => 1,
        arrived_at => \'now()'
    });
}

sub create_empty_container {
    my ($self, $container_id) = @_;

    my $container = $self->schema->resultset('Public::Container')->find_or_create({ id => $container_id});
}

1;
