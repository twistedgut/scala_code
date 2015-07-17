package Test::XTracker::Schema::ResultSet::Public::Shipment;
use NAP::policy qw/test class/;
use FindBin::libs;
BEGIN {
    extends 'NAP::Test::Class';
    with qw/Test::Role::WithSchema Test::Role::DBSamples/;
};

=head1 NAME

Test::XTracker::Schema::ResultSet::Public::Shipment - Unit tests for
XTracker::Schema::ResultSet::Public::Shipment

=cut

use Test::XT::Data;
use Test::XTracker::Data;
use Test::XTracker::Data::Shipping;
use Test::MockModule;
use XTracker::Constants::FromDB qw(
    :storage_type
    :shipment_status
    :shipment_item_status
    :allocation_status
);
use XTracker::Config::Local qw( config_var );

sub test__search_by_channel_ids :Tests {
    my ($self) = @_;

    SKIP: {
    skip 'Need at least 2 channels to perform this test' unless $self->schema->resultset('Public::Channel')->count > 1;

    my $a_channel = $self->schema->resultset('Public::Channel')->first;
    my $another_channel = $self->schema->resultset('Public::Channel')->search({
        id => { '!=' => $a_channel->id }
    })->first;

    for my $test (
        {
            name    => 'Filter by channel-id',
            setup   => {
                shipments => [
                    { channel => $a_channel,        comment => 'Should be found' },
                    { channel => $another_channel,  comment => 'Should not be found' },
                ],
                params => [$a_channel->id],
            },
            expect => {
                shipment_comments => [
                    'Should be found'
                ],
            }
        }
    ) {
        subtest $test->{name} => sub {
            my $resultset = $self->_create_search_by_channel_ids_test_data($test);

            my @shipment_comments = $resultset->search_by_channel_ids(
                $test->{setup}->{params}
            )->get_column('comment')->all;

            eq_or_diff(\@shipment_comments, $test->{expect}->{shipment_comments});
        };
    }

    } # End of SKIP

}

sub _create_search_by_channel_ids_test_data {
    my ($self, $test) = @_;

    my @shipment_ids = map {
        my $shipment_def = $_;

        my $pids = Test::XTracker::Data->find_or_create_products({
            how_many => 1,
            channel_id => $shipment_def->{channel}->id,
        });

        my ($order, undef) = Test::XTracker::Data->create_db_order({
            pids => $pids,
            base => {
                channel_id  => $shipment_def->{channel}->id,
                comment     => $shipment_def->{comment}
            }
        });
        $order->shipments->first->id;
    } @{$test->{setup}->{shipments}};

    return $self->schema->resultset('Public::Shipment')->search({
        'me.id' => \@shipment_ids
    })
}

sub _create_order_shipment_data {
    my ($self) = @_;

    my $orders = {};

    my $now = $self->schema->db_now();
    for my $order (
        {
            name            => 'valid1',
            update_params   => {
                sla_priority                => 4,
                sla_cutoff                  => $now->clone->add( hours => 1 ),
                wms_initial_pick_priority   => 20,
                wms_bump_pick_priority      => 1,
                wms_bump_deadline           => $now->clone->subtract( hours => 1),
                wms_deadline                => $now->clone->add( hours => 1 ),
            },
        },
        {
            name            => 'valid2',
            update_params   => {
                sla_priority                => 3,
                sla_cutoff                  => $now->clone(),
                wms_initial_pick_priority   => 20,
                wms_bump_pick_priority      => 2,
                wms_bump_deadline           => $now->clone->add( hours => 1),
                wms_deadline                => $now->clone(),
            },
        },
        {
            name            => 'valid3',
            update_params   => {
                sla_priority                => 2,
                sla_cutoff                  => $now->clone->subtract( hours => 1),
                wms_initial_pick_priority   => 20,
                wms_bump_pick_priority      => 3,
                wms_bump_deadline           => $now->clone->subtract( hours => 3),
                wms_deadline                => $now->clone->subtract( hours => 1 ),
            },
        },

        # shipments with unallocated items should be ignored
        (config_var('PRL','rollout_phase')
            ? ({
                name                    => 'not_allocated',
                update_params           => {
                    sla_priority                => 14,
                    sla_cutoff                  => $now->clone->subtract( hours => 1),
                    wms_initial_pick_priority   => 20,
                    wms_deadline                => $now->clone->subtract( hours => 1 ),
                },
                has_unallocated_items   => 1,
            })
            : ()
        ),
        # Create an order with very low sla_priority, but with the 'is_prioritised' flag
        {
            name            => 'is_prioritised',
            update_params   => {
                sla_priority                => 15,
                sla_cutoff                  => $now->clone(),
                is_prioritised              => 1,
                wms_initial_pick_priority   => 20,
                wms_deadline                => $now->clone(),
            },
        },
        # Now create one that is in 'Hold' status (should be ignored)
        {
            name            => 'hold',
            update_params   => {
                shipment_status_id => $SHIPMENT_STATUS__HOLD,
            },
        },
        # Create one where the items are all Picked
        {
            name                => 'picked',
            no_of_products      => 1,
            no_of_picked_items  => 1,
        },
        {
            name                => 'partially_picked',
            no_of_products      => 2,
            no_of_picked_items  => 1,
            update_params   => {
                sla_priority                => 1,
                wms_initial_pick_priority   => 20,
            },
        },
        # Create an order that has a high sla_priorty,
        # but has not reached it's nominated_earliest_selection_time...
        {
            name            => 'not_reached_est',
            update_params   => {
                sla_priority                        => 1,
                nominated_earliest_selection_time   => $now->clone->add( days => 1 ),
                wms_initial_pick_priority           => 20,
            },
        },
        # And one that has
        {
            name            => 'reached_est',
            update_params   => {
                sla_priority                      => 10,
                nominated_earliest_selection_time => $now->clone->subtract( days => 1 ),
                wms_initial_pick_priority         => 20,
            },
        },
        # Two more that are the same but the 2nd is further past to it's sla_cutoff
        {
            name            => 'sla_cutoff_last',
            update_params   => {
                sla_priority                => 20,
                sla_cutoff                  => $now->clone->subtract( days => 1 ),
                wms_initial_pick_priority   => 20,
                wms_deadline                => $now->clone->subtract( days => 1 ),
            },
        },
        {
            name            => 'sla_cutoff_first',
            update_params   => {
                sla_priority                => 20,
                sla_cutoff                  => $now->clone->subtract( days => 2 ),
                wms_initial_pick_priority   => 20,
                wms_deadline                => $now->clone->subtract( days => 2 ),
            },
        },
    ) {
        $orders->{$order->{name}} = $self->test_data->new_order(
            products => (defined($order->{no_of_products}) ? $order->{no_of_products} : 1)
        );
        $orders->{$order->{name}}->{'shipment_object'}->update($order->{update_params})
            if defined($order->{update_params});

        $orders->{$order->{name}}->{'shipment_object'}->shipment_items->search_related('allocation_items')->update({
            status_id => $ALLOCATION_STATUS__REQUESTED,
        }) if $order->{has_unallocated_items};

        $orders->{$order->{name}}->{'shipment_object'}->search_related('shipment_items', {
        }, {
            rows => $order->{no_of_picked_items},
        })->update({
            shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PICKED
        }) if $order->{no_of_picked_items};
    }

    my $shipment_rs = $self->schema->resultset('Public::Shipment')->search({
        id => [map { $orders->{$_}->{'shipment_id'} } keys %$orders],
    });

    return ($shipment_rs, $orders);
}

# Test get_order_selection_list()
sub test__get_order_selection_list :Tests {
    my ($self) = @_;

    my ($shipment_rs, $orders) = $self->_create_order_shipment_data();

    for my $test (
        {
            name    => 'Select orders including held for nominated selection',
            setup   => {
                use_wms_priority_fields         => 0,
                get_order_selection_list_params => {},
            },
            result  => {
                shipment_ids => [
                    $orders->{'is_prioritised'}->{'shipment_id'},
                    $orders->{'partially_picked'}->{'shipment_id'},
                    $orders->{'valid3'}->{'shipment_id'},
                    $orders->{'valid2'}->{'shipment_id'},
                    $orders->{'valid1'}->{'shipment_id'},
                    $orders->{'reached_est'}->{'shipment_id'},
                    $orders->{'sla_cutoff_first'}->{'shipment_id'},
                    $orders->{'sla_cutoff_last'}->{'shipment_id'},
                    $orders->{'not_reached_est'}->{'shipment_id'},
                ],
            },
        },

        {
            name    => 'Select orders excluding held for nominated selection',
            setup   => {
                get_order_selection_list_params => {
                    use_wms_priority_fields                 => 0,
                    exclude_held_for_nominated_selection    => 1,
                },
            },
            result  => {
                shipment_ids => [
                    $orders->{'is_prioritised'}->{'shipment_id'},
                    $orders->{'partially_picked'}->{'shipment_id'},
                    $orders->{'valid3'}->{'shipment_id'},
                    $orders->{'valid2'}->{'shipment_id'},
                    $orders->{'valid1'}->{'shipment_id'},
                    $orders->{'reached_est'}->{'shipment_id'},
                    $orders->{'sla_cutoff_first'}->{'shipment_id'},
                    $orders->{'sla_cutoff_last'}->{'shipment_id'},
                ],
            },
        },

        {
            name    => 'Select orders including held for nominated selection using wms_priority',
            setup   => {
                use_wms_priority_fields         => 1,
                get_order_selection_list_params => {},
            },
            result  => {
                shipment_ids => [
                    $orders->{'is_prioritised'}->{'shipment_id'},
                    $orders->{'valid1'}->{'shipment_id'},
                    $orders->{'valid3'}->{'shipment_id'},
                    $orders->{'sla_cutoff_first'}->{'shipment_id'},
                    $orders->{'sla_cutoff_last'}->{'shipment_id'},
                    $orders->{'valid2'}->{'shipment_id'},
                    $orders->{'partially_picked'}->{'shipment_id'},
                    $orders->{'reached_est'}->{'shipment_id'},
                    $orders->{'not_reached_est'}->{'shipment_id'},
                ],
            },
        },
    ) {
        subtest $test->{name} => sub {

            my $mock_shipment_rs = Test::MockModule->new('XTracker::Schema::ResultSet::Public::Shipment');
            $mock_shipment_rs->mock('use_wms_priority_fields', $test->{setup}->{use_wms_priority_fields});

            my @shipments = $shipment_rs->get_order_selection_list(
                $test->{setup}->{get_order_selection_list_params}
            );

            eq_or_diff([map { $_->id } @shipments], $test->{result}->{shipment_ids},
                'Shipment ids are as expected and in correct order');

        };
    }
}

sub _create_sample_shipment_data {
    my ($self) = @_;

    # Request some samples
    my $channel = Test::XTracker::Data->any_channel;
    my $variant = (Test::XTracker::Data->grab_products({
        channel_id => $channel->id,
        force_create => 1,
    }))[1][0]->{variant};
    my $samples = {};

    my $valid_counter = 0;
    my $now = $self->schema->db_now();
    for my $sample (
        {
            name                        => 'valid1',
            channel                     => $channel,
            variant                     => $variant,
            sla_priority                => 5,
            sla_cutoff                  => $now->clone->add( hours => 5 ),
            wms_initial_pick_priority   => 20,
            wms_deadline                => $now->clone->add( hours => 1 ),
            wms_bump_deadline           => $now->clone->add( hours => 1 ),
            wms_bump_pick_priority      => 1,
            is_prioritised              => 0,
        },
        {
            name                        => 'valid2',
            channel                     => $channel,
            variant                     => $variant,
            sla_priority                => 4,
            sla_cutoff                  => $now->clone->add( hours => 4 ),
            wms_initial_pick_priority   => 20,
            wms_deadline                => $now->clone->add( hours => 2 ),
            wms_bump_deadline           => $now->clone->subtract( hours => 2 ),
            wms_bump_pick_priority      => 2,
            is_prioritised              => 1,
        },
        {
            name                        => 'valid3',
            channel                     => $channel,
            variant                     => $variant,
            sla_priority                => 3,
            sla_cutoff                  => $now->clone->add( hours => 3 ),
            wms_initial_pick_priority   => 20,
            wms_deadline                => $now->clone->add( hours => 3 ),
            wms_bump_deadline           => $now->clone->add( hours => 3 ),
            wms_bump_pick_priority      => 3,
            is_prioritised              => 0,
        },
        {
            name                        => 'valid4',
            channel                     => $channel,
            variant                     => $variant,
            sla_priority                => 2,
            sla_cutoff                  => $now->clone->add( hours => 2 ),
            wms_initial_pick_priority   => 20,
            wms_deadline                => $now->clone->add( hours => 4 ),
            wms_bump_deadline           => $now->clone->subtract( hours => 4 ),
            wms_bump_pick_priority      => 1,
            is_prioritised              => 0,
        },
        {
            name                        => 'valid5',
            channel                     => $channel,
            variant                     => $variant,
            sla_priority                => 1,
            sla_cutoff                  => $now->clone->add( hours => 1 ),
            wms_initial_pick_priority   => 20,
            wms_deadline                => $now->clone->add( hours => 5 ),
            wms_bump_deadline           => $now->clone->add( hours => 5 ),
            wms_bump_pick_priority      => 1,
            is_prioritised              => 0,
        },
        {
            name                        => 'picked',
            channel                     => $channel,
            variant                     => $variant,
            sla_priority                => 1,
            sla_cutoff                  => $now->clone->add( hours => 1 ),
            wms_initial_pick_priority   => 20,
            wms_deadline                => $now->clone->add( hours => 5 ),
            wms_bump_deadline           => $now->clone->add( hours => 5 ),
            wms_bump_pick_priority      => 1,
            is_prioritised              => 0,
            shipment_status_id          => $SHIPMENT_STATUS__HOLD
        },
    ) {
        $samples->{$sample->{name}} = $self->db__samples__create_shipment({
            channel_id    => $sample->{channel}->id(),
            variant_id    => $sample->{variant}->id(),
        });
        $samples->{$sample->{name}}->update({
            sla_priority                => $sample->{sla_priority},
            sla_cutoff                  => $sample->{sla_cutoff},
            wms_initial_pick_priority   => $sample->{wms_initial_pick_priority},
            wms_deadline                => $sample->{wms_deadline},
            wms_bump_deadline           => $sample->{wms_bump_deadline},
            wms_bump_pick_priority      => $sample->{wms_bump_pick_priority},
            is_prioritised              => $sample->{is_prioritised},
            ( $sample->{shipment_status_id}
                ? ( shipment_status_id => $sample->{shipment_status_id} )
                : ()
            )
        });
    }

    my $shipment_rs = $self->schema->resultset('Public::Shipment')->search({
        id => [map { $samples->{$_}->id() } keys %$samples]
    });

    return ($shipment_rs, $samples);
}

# Test get_transfer_selection_list()
sub test__get_transfer_selection_list :Tests() {
    my ($self) = @_;

    my ($shipment_rs, $samples) = $self->_create_sample_shipment_data();

    # Need to try prioritising with wms_priority fields and without (in production these
    # will be used when SOS is enabled)
    for my $test (
        {
            name    => 'Not using wms-priority fields',
            setup   => {
                use_wms_priority_fields             => 0,
                get_transfer_selection_list_params  => {},
            },
            result  => {
                shipment_ids => [
                    $samples->{"valid2"}->id(), # (Priority 4, but has is_prioritised flag set)
                    $samples->{"valid5"}->id(), # (Priority 1)
                    $samples->{"valid4"}->id(), # (Priority 2)
                    $samples->{"valid3"}->id(), # (Priority 3)
                    $samples->{"valid1"}->id(), # (Priority 5)
                ]
            }
        },
        {
            name    => 'Not using wms-priority fields, exclude un-prioritised',
            setup   => {
                use_wms_priority_fields             => 0,
                get_transfer_selection_list_params  => {
                    exclude_non_prioritised_samples => 1,
                },
            },
            result  => {
                shipment_ids => [
                    $samples->{"valid2"}->id(), # (Has is_prioritised flag set)
                ]
            }
        },
        {
            name    => 'Using wms-priority fields',
            setup   => {
                use_wms_priority_fields             => 1,
                get_transfer_selection_list_params  => {},
            },
            result  => {
                shipment_ids => [
                    $samples->{"valid2"}->id(), # (Bump-priority 2, but has is_prioritised flag set)
                    $samples->{"valid4"}->id(), # (Bump-priority 4)
                    $samples->{"valid5"}->id(), # (Init-priority 20, SLA +1 hour, deadline + 5 hours)
                    $samples->{"valid3"}->id(), # (Init-priority 20, SLA +3 hour, deadline + 3 hours)
                    $samples->{"valid1"}->id(), # (Init-priority 20, SLA +5 hours, deadline + 1 hours)
                ]
            }
        },
    ) {
        subtest $test->{name} => sub {

            my $mock_shipment_rs = Test::MockModule->new('XTracker::Schema::ResultSet::Public::Shipment');
            $mock_shipment_rs->mock('use_wms_priority_fields', $test->{setup}->{use_wms_priority_fields});


            my @shipments = $shipment_rs->get_transfer_selection_list(
                $test->{setup}->{get_transfer_selection_list_params}
            );

            eq_or_diff([map { $_->id } @shipments], $test->{result}->{shipment_ids},
                'Correct samples returned in correct order');
        };
    }
}

sub test__get_selection_list : Tests() {
    my $self = shift;

    my $rs = $self->schema->resultset('Public::Shipment')->get_selection_list;
    # Test this as we had a bug where the resultset worked but as we use a
    # value in order_by that is created in literal sql in the values for
    # +select/+columns, calling related_resultset didn't as those values get
    # dropped
    lives_ok( sub { $rs->related_resultset('allocations')->slice(0,0)->single },
        q{calling related_resultset shouldn't die});

    subtest 'customer and sample should be in resultset' => sub {
        my @shipments = (
            $self->test_data->new_order->{shipment_object},
            $self->db__samples__create_shipment,
        );
        is( $rs->search({'me.id' => [map { $_->id } @shipments]})->count, 2,
            'both shipment classes in resultset' );
    };

    subtest 'Test exclude_non_prioritised_samples flag' => sub {
        # Add a prioritised sample and a non-prioritised non-sample shipment
        my $channel = Test::XTracker::Data->any_channel;
        my $variant = (Test::XTracker::Data->grab_products({
            channel_id => $channel->id,
            force_create => 1,
        }))[1][0]->{variant};
        my $shipments = {};

        $shipments->{"prioritised_sample"} = $self->db__samples__create_shipment({
            channel_id    => $channel->id,
            variant_id    => $variant->id,
        });
        $shipments->{"prioritised_sample"}->update({ is_prioritised => 1 });
        $shipments->{"unprioritised_sample"} = $self->db__samples__create_shipment({
            channel_id    => $channel->id,
            variant_id    => $variant->id,
        });

        $shipments->{"normal_shipment"} = $self->test_data->new_order( products => 1 )->{'shipment_object'};

        my @valid_ids = map { $_->id() } values %$shipments;

        # Now make sure that 'exclude_non_prioritised_samples' picks up only prioritised sample shipments,
        # but is ignored in the case of normal shipments
        my $shipments_rs = $self->schema->resultset('Public::Shipment')->get_selection_list({
            exclude_non_prioritised_samples => 1,
        });
        $shipments_rs = $shipments_rs->search({
            id => \@valid_ids,
        });
        my @shipment_rows = $shipments_rs->all();
        my %ship_ids = map { $_->id() => 1 } @shipment_rows;

        is_deeply(\%ship_ids, {
            $shipments->{"prioritised_sample"}->id()=> 1,
            $shipments->{"normal_shipment"}->id()   => 1,
        }, 'Only prioritised sample shipments, but any normal shipments returned when using "exclude_non_prioritised_samples"');
    };
}
