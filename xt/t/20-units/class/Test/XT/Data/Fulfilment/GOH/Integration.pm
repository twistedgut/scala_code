package Test::XT::Data::Fulfilment::GOH::Integration;

use NAP::policy "tt", "test", "class";
use FindBin::libs;
use Test::XTracker::RunCondition prl_phase => 2;
use Test::XTracker::LoadTestConfig;

BEGIN {
    extends 'NAP::Test::Class';
    with 'Test::Role::WithGOHIntegration'
}

use Guard;

use Test::XTracker::Data::PackRouteTests;
use Test::MockObject::Extends;
use Test::Fatal;
use Test::XT::Data::Container;
use Test::XTracker::Data::Order;
use Test::XT::Fixture::Fulfilment::Shipment;

use XTracker::Config::Local qw/config_var/;
use XT::Data::Fulfilment::GOH::Integration;
use XTracker::Database::Distribution qw /get_packing_shipment_list/;
use XTracker::Constants::FromDB qw/
    :allocation_status
    :container_status
    :pack_lane_attribute
    :prl_delivery_destination
    :prl
/;
use XTracker::Constants qw(
    :application
);
use vars qw/
    $PRL__DEMATIC
    $PRL__GOH
    $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
/;

sub test_instantiation :Tests {
    my $self = shift;

    lives_ok
        {
            XT::Data::Fulfilment::GOH::Integration->new({
                $self->process_constructor_params_integration
            })
        }
        'Use valid type to instantiate process object';

    # Check that using incorrect type results in Moose exception.
    # Even though this is like testing Moose, we still need this
    # as controller code for corresponding page relies on that
    # particular exception class.
    throws_ok
        {
            XT::Data::Fulfilment::GOH::Integration->new({
                prl_delivery_destination_row => 'lalalala',
            })
        }
        'Moose::Exception::ValidationFailedForInlineTypeConstraint',
        'Try to use use some nonsene as type';
}

sub check_parameters_for_next_action :Tests {
    my $self = shift;

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration
    });

    is(
        $process->user_message_scan_container,
        $process->user_message,
        'As we do not have container ID yet, user asked to scan one'
    );
    is(
        $process->next_scan_container,
        $process->next_scan,
        'Next entity to be scanned is "container"'
    );
    is(
        'scan_' . $process->next_scan_container,
        $process->next_scan_action,
        'Next default action is to scan container'
    );
    cmp_deeply(
        [$process->delivery_destination_id],
        $process->next_action_args,
        'Check arguments for next default action'
    );

    note 'Update process as it scanned container';
    $process->set_container(
        Test::XT::Data::Container->create_new_containers()->[0]
    );

    is(
        $process->user_message_scan_sku,
        $process->user_message,
        'User is promted to scan SKU'
    );
    is(
        $process->next_scan_sku,
        $process->next_scan,
        'Next entity to be scanned is "SKU"'
    );
    is(
        'scan_' . $process->next_scan_sku,
        $process->next_scan_action,
        'Next default action is to scan SKU'
    );
    cmp_deeply(
        [$process->delivery_destination_id, $process->container_id],
        $process->next_action_args,
        'Check arguments for next default action'
    );
}

sub show_missing_button_for_direct_lane :Tests {
    my $self = shift;

    subtest 'No missing button for scan container step' => sub {
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            next_container_id_to_scan => undef,
        });

        ok(
            ! $process->show_missing_button,
            'No "Missing" button for container'
        );
    };

    subtest 'Show missing button only when expecting SKU' => sub {
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            rail_allocation_item_rows => [
                $self
                    ->create_allocation_item_at_delivery_destination(
                        $PRL_DELIVERY_DESTINATION__GOH_DIRECT
                    )
            ],
        });

        $process->set_container(
            Test::XT::Data::Container->create_new_containers()->[0]
        );

        ok(
            $process->show_missing_button,
            'Show "Missing" button for SKU'
        );
    };

    subtest 'Omit missing button if nothing is expected to be scanned' => sub {

        my ($integration_container, $allocation_item_1,
            $allocation_item_2, $allocation_item_3) =
            $self->prepare_different_mix_groups;

        $_->add_to_integration_container({
            integration_container => $integration_container,
        }) for $allocation_item_1, $allocation_item_2;


        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            integration_container_row => $integration_container,
            rail_allocation_item_rows => [ $allocation_item_3 ],
        });

        ok(
            ! $process->show_missing_button,
            'Nothing is supposed to be scanned so no Missing button either'
        );
    };
}

sub show_missing_button_for_integration_lane :Tests {
    my $self = shift;

    note 'For Integration lane show "Missing" button if user '
        .'is required to scan secific container';

    note 'Create Process that does not have required container';
    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration,
        next_container_id_to_scan => undef,
    });

    ok(
        ! $process->show_missing_button,
        'No "Missing" button for container'
    );

    note 'Pretend that empty container was scanned';
    $process->set_container(
        Test::XT::Data::Container->create_new_containers()->[0]
    );

    ok(
        $process->show_missing_button,
        'Show "Missing" button for SKU'
    );

    note 'Create process that reqiores user to scan particular container';
    $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration,
        next_container_id_to_scan => Test::XT::Data::Container->create_new_containers()->[0]->as_id,
    });

    ok(
        !! $process->show_missing_button,
        'Show "Missing" button for container'
    );
}

sub set_container :Tests {
    my $self = shift;

    note 'This test relies on the "required_container_id" provided '
        .'at instantiation of process object.';

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration,
        next_container_id_to_scan => NAP::DC::Barcode::Container::Tote->new_from_id('T1234567A')->as_id,
    });

    throws_ok
        {
            $process->set_container('lalalala')
        }
        'NAP::DC::Exception::Barcode',
        'Validation for Container ID to be barcode';

    note 'Try to set valid container but not from DCD queue';
    throws_ok
        {
            $process->set_container(
                NAP::DC::Barcode::Container::Tote->new_from_id('T1111111A'),
                'at_scanning'
            )
        }
        'XT::Exception::Data::Fulfilment::GOH::Integration::UnexpectedContainer',
        'Only containers from DCD queue are allowed to be scanned';

    lives_ok
        {
            $process->set_container(
                NAP::DC::Barcode::Container::Tote->new_from_id('T1234567A')
            )
        }
        'Container from DCD queue is successfully set';

    subtest 'Try to use container that was just marked as complete' => sub {
        # system should prevent from using such containers until
        # they are confirmed as arrived on Packing

        my $allocation_item = $self
            ->create_allocation_item_at_delivery_destination(
                $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
            );

        note 'Progress container to the Complete state';
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct
        });

        my $sku = $allocation_item->shipment_item->get_sku;
        my ($container) = Test::XT::Data::Container->create_new_container_rows;
        $process->set_container( $container->id );
        $process->set_sku( $sku );
        $process->commit_scan;

        my $integration_container = $process->integration_container_row;
        $integration_container->mark_as_complete;

        note 'Instantiate new process object and try to use previous container';
        $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct
        });

        isa_ok(
            exception {
                $process->set_container($container->id);
            },
            'XT::Exception::Data::Fulfilment::GOH::Integration::ScanRoutedContainer',
            'Consider container as invalid'
        );
    };
}

sub check_user_message_scan_container :Tests {
    my $self = shift;

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct
    });

    my $scan_empty_msg = 'Please scan an empty tote';

    is(
        $process->user_message,
        $scan_empty_msg,
        'Direct lane always asks for empty container'
    );

    note 'Make sure that Integration lane has content';
    my $sku = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
        )
        ->shipment_item
        ->get_sku;

    $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration,
        dcd_integration_container_rs => scalar(
            $self->schema
                ->resultset('Public::IntegrationContainer')
                ->search({ 1 => 0 })
            ),
    });

    is(
        $process->user_message,
        $scan_empty_msg,
        'If nothing on Dematic queue for Integration lane '
            . 'ask for empty container'
    );

    note 'Make sure DCD queue has something';
    $self->process_constructor_params_integration;
    my $standalone_allocation_item = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
        );

    $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration,
        rail_allocation_item_rows => [$standalone_allocation_item],
    });

    is(
        $process->user_message,
        $scan_empty_msg,
        'There are containers in Dematic queue, '
            . 'but first garment on the rail does not '
            . 'relate to any of them',
    );

    # case when user need to scan specific container
    $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration,
        next_container_id_to_scan => 'T1234567A',
    });

    is(
        $process->user_message,
        'Please scan T1234567A from Dematic queue',
        'User is asked to scan container from Dematic queue'
    );
}

sub mark_container_full__check_if_allocation_is_updated :Tests {
    my $self = shift;

    note 'Create an allocation with one item';
    note 'And put that item into container at GOH Integration';
    my $allocation_item =
        $self->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
        )->allocation->allocation_items->first;

    my ($container) =Test::XT::Data::Container->create_new_container_rows;
    my $integration_container = $self->schema
        ->resultset('Public::IntegrationContainer')
        ->create({
            container_id => $container->id,
            prl_id       => $PRL__GOH,
        });
    $allocation_item->add_to_integration_container({
        integration_container => $integration_container,
    });

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration,
    });
    $process->set_container( $container->id );

    note 'Mark GOH Integration container as completed';
    $process->mark_container_full({
        operator_id => $APPLICATION_OPERATOR_ID,
    });

    $allocation_item->discard_changes;
    ok(
        $allocation_item->allocation->is_picked,
        'As a result of GOH integration allocation was picked'
    );
}

sub try_to_use_dcd_container_at_direct_lane :Tests {
    my $self = shift;

    note 'Create a delivery destination for Direct lane';
    my $delivery_destination = $self->get_delivery_destination(
        $PRL_DELIVERY_DESTINATION__GOH_DIRECT
    );

    note 'Create an integration container record for container that came from DCD';
    my ($container) = Test::XT::Data::Container->create_new_container_rows;
    my $integration_container = $self->schema
        ->resultset('Public::IntegrationContainer')->create({
            container_id => $container->id,
            prl_id       => $PRL__GOH,
            from_prl_id  => $PRL__DEMATIC,
        });

    note 'Try to use DCD container at Direct lane';
    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        prl_delivery_destination_row => $delivery_destination,
    });

    throws_ok {
            $process->set_container(
                $integration_container->container_id, 'at_scanning'
            );
        }
        'XT::Exception::Data::Fulfilment::GOH::Integration::AttemptToUseDCDContainerAtDirectLane',
        'Prevent users to use DCD containers at Direct lane';
}

sub mark_container_full__non_happy_pathes :Tests {
    my $self = shift;

    my $delivery_destination = $self->get_delivery_destination(
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    );

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        prl_delivery_destination_row => $delivery_destination,
    });

    throws_ok {
            $process->mark_container_full({
                operator_id => $APPLICATION_OPERATOR_ID,
            });
        }
        'XT::Exception::Data::Fulfilment::GOH::Integration::NoIntegrationContainer',
        'Correct exception is thrown if no integration container';

    $process = XT::Data::Fulfilment::GOH::Integration->new({
        prl_delivery_destination_row => $delivery_destination,
        integration_container_row => $self->schema
            ->resultset('Public::IntegrationContainer')
            ->new_result({
                # does not matter container ID as long as it is valid one
                container_id => 'T1234567',
            })
    });

    throws_ok {
            $process->mark_container_full({
                operator_id => $APPLICATION_OPERATOR_ID,
            });
        }
        'XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsEmpty',
        'Correct exception is thrown if container is empty';


    my $create_integration_container_cr = sub {
        my ($container) =Test::XT::Data::Container->create_new_container_rows;
        $self->schema->resultset('Public::IntegrationContainer')->create({
            container_id => $container->id,
            prl_id       => $PRL__GOH,
            from_prl_id  => $PRL__DEMATIC,
        });
    };

    my $integration_container = $create_integration_container_cr->();

    $integration_container->mark_as_complete({
        operator_id => $APPLICATION_OPERATOR_ID,
    });
    $process = XT::Data::Fulfilment::GOH::Integration->new({
        prl_delivery_destination_row => $delivery_destination,
        integration_container_row    => $integration_container,
    });

    throws_ok {
            $process->mark_container_full({
                operator_id => $APPLICATION_OPERATOR_ID,
            });
        }
        'XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsAlreadyComplete',
        'Correct exception is thrown if container was previousely completed ';


    # The idea is to mock integration container row and check
    # if its "mark_as_complete" method was called while calling
    # "mark_container_full"
    my $called;
    $integration_container = Test::MockObject::Extends->new(
        $create_integration_container_cr->()
    );
    $integration_container->mock(
        mark_as_complete => sub { $called = 1 },
    );

    XT::Data::Fulfilment::GOH::Integration
        ->new({
            prl_delivery_destination_row => $delivery_destination,
            integration_container_row    => $integration_container,
        })
        ->mark_container_full({
            operator_id => $APPLICATION_OPERATOR_ID,
        });

    is
        $called,
        1,
        'mark_container_full on integration container record was called';

}

sub user_message :Tests {
    my $self = shift;

    my $container = Test::XT::Data::Container->create_new_containers()->[0];

    note 'Start container on Direct lane and abandon it';
    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct,
        next_container_id_to_scan => undef,
    });
    $process->set_container( $container->as_barcode );
    $process->set_sku(
         $self
            ->create_allocation_item_at_delivery_destination(
                $PRL_DELIVERY_DESTINATION__GOH_DIRECT
            )
            ->shipment_item
            ->get_sku
    );
    $process->commit_scan;

    ok(
        !$process->is_container_resumed,
        'Process is not resuming container'
    );
    cmp_deeply(
        $process->next_action_query_values,
        {},
        'Next action is not informed about container resuming'
    );


    note 'Resume the container';
    $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct
    });
    $process->set_container( $container->as_barcode );
    $process->commit_scan;

    ok(
        $process->is_container_resumed,
        'This is resuming started container'
    );
    cmp_deeply(
        $process->next_action_query_values,
        {
            is_container_resumed => 1,
        },
        'Next action is aware that we just resumed a container'
    );
}

sub next_sku_to_scan :Tests {
    my $self = shift;

    subtest "Incoming rail is empty" => sub {
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            rail_allocation_item_rows => [],
        });

        is(
            $process->next_sku_to_scan,
            '',
            'Nothing is expected for SKU'
        );
    };


    subtest "Rail has content but container is empty" => sub {

        my ($allocation_item_1, $allocation_item_2) =
            map {
                $self->create_allocation_item_at_delivery_destination(
                    $PRL_DELIVERY_DESTINATION__GOH_DIRECT
                )
            } 1..2;

        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            rail_allocation_item_rows => [$allocation_item_1, $allocation_item_2],
        });

        is(
            $process->next_sku_to_scan,
            $allocation_item_1->shipment_item->get_sku,
            'First SKU is expected to be scanned'
        );
    };


    subtest "Rail and container have stock of same mix group" => sub {

        my ($integration_container, $allocation_item_1,
            $allocation_item_2) =
            $self->prepare_different_mix_groups;

        note 'Place first allocation item into container';
        $allocation_item_1->add_to_integration_container({
            integration_container => $integration_container,
        });

        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            integration_container_row    => $integration_container,
            rail_allocation_item_rows    => [$allocation_item_2]
        });

        is(
            $process->next_sku_to_scan,
            $allocation_item_2->shipment_item->get_sku,
            'SKU from second allocation item  is expected to be scanned'
        );
    };


    subtest "Rail and container have stock of different mix group" => sub {

        my ($integration_container, $allocation_item_1,
            $allocation_item_2, $allocation_item_3) =
            $self->prepare_different_mix_groups;

        note 'Place first allocation into container';
        $_->add_to_integration_container({
            integration_container => $integration_container,
        }) for ($allocation_item_1, $allocation_item_2);

        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            integration_container_row    => $integration_container,
            rail_allocation_item_rows    => [$allocation_item_3]
        });

        is(
            $process->next_sku_to_scan,
            '',
            'Even though rail has allocation item, no more SKUs is expected to be scanned'
        );
    };
}

sub user_message_scan_sku :Tests {
    my $self = shift;

    my ($integration_container, $allocation_item_1,
        $allocation_item_2, $allocation_item_3) =
        $self->prepare_different_mix_groups;

    note 'Place first item into container';
    $allocation_item_1->add_to_integration_container({
        integration_container => $integration_container,
    });

    subtest 'About to scan SKU with same mix group as in container' => sub {
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            integration_container_row    => $integration_container,
            rail_allocation_item_rows    => [$allocation_item_2]
        });

        my $user_message = sprintf
            'Please scan %s SKU from the',
            $allocation_item_2->shipment_item->get_sku;

        like(
            $process->user_message_scan_sku,
            qr/$user_message/,
            'System demands to scan remaining SKU from first allocation'
        );
    };

    subtest 'About to scan SKU with different mix group as in container' => sub {

        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            integration_container_row    => $integration_container,
            rail_allocation_item_rows    => [$allocation_item_3]
        });

        my $user_message = sprintf
            'Please mark container %s as complete',
            $integration_container->container_id;

        like(
            $process->user_message_scan_sku,
            qr/$user_message/,
            'System asks to mark container as complete'
        );
    };
}

sub set_sku :Tests {
    my $self = shift;

    my ($integration_container, $allocation_item_1,
        $allocation_item_2, $allocation_item_3) =
        $self->prepare_different_mix_groups;

    note 'Place first item into container';
    $allocation_item_1->add_to_integration_container({
        integration_container => $integration_container,
    });
    is ($integration_container->container->status_id, $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS,
        "Container row has correct status");

    subtest 'Try to use SKU that is not expected to be on the rail' => sub {
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            integration_container_row    => $integration_container,
            rail_allocation_item_rows    => [$allocation_item_2]
        });

        isa_ok(
            exception {
                $process->set_sku(
                    $allocation_item_3->shipment_item->get_sku
                );
            },
            'XT::Exception::Data::Fulfilment::GOH::Integration::UnknownSku',
            'Unknown SKU is detected'
        );

    };

    subtest 'Try to use SKU that is not expected to be on the rail but could be on problem rail' => sub {
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            integration_container_row    => $integration_container,
            rail_allocation_item_rows    => []
        });

        # If we update the allocation status to delivered but pretend the item didn't
        # have delivery_order set, it should look like it could be on the problem rail,
        # and we should be allowed to scan it.
        $allocation_item_2->update({
            delivery_order => undef,
        });
        $allocation_item_2->allocation->update({
            status_id => $ALLOCATION_STATUS__DELIVERED,
        });

        lives_ok {
            $process->set_sku(
                    $allocation_item_2->shipment_item->get_sku
            );
        } 'SKU from problem rail can be scanned';

    };

    subtest 'Try to use SKU from rail but different mix group than in current container' => sub {
        my $process = XT::Data::Fulfilment::GOH::Integration->new({
            $self->process_constructor_params_direct,
            integration_container_row    => $integration_container,
            rail_allocation_item_rows    => [$allocation_item_2, $allocation_item_3]
        });

        isa_ok(
            exception {
                $process->set_sku(
                    $allocation_item_3->shipment_item->get_sku
                );
            },
            'XT::Exception::Data::Fulfilment::GOH::Integration::MixGroupMismatch',
            'Mix group mismatch is detected'
        );
    };
}

# The idea of test: to have two items allocation and one item
# allocation, second item of first allocation is not delivered
# - it is one to be checked on problem rail.
#
sub check_prompt_to_have_a_look_onto_problem_rail :Tests {
    my $self = shift;

    my ($integration_container, $allocation_item_1,
        $allocation_item_2, $allocation_item_3) =
        $self->prepare_different_mix_groups;

    note 'Place first item from first allocationn into container';
    $allocation_item_1->add_to_integration_container({
        integration_container => $integration_container,
    });

    note 'Make sure second item was not delivered';
    $allocation_item_2->update({
        delivered_at   => undef,
        delivery_order => undef,
    });

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct,
        integration_container_row    => $integration_container,
        rail_allocation_item_rows    => [$allocation_item_3]
    });

    is(
        $process->next_sku_to_scan,
        $allocation_item_2->shipment_item->get_sku,
        'Process suggests to check second SKU...'
    );

    ok(
        $process->prompt_to_check_problem_rail,
        '... on Problem rail'
    );
}

sub scan_invalid_sku_barcode :Tests {
    my $self = shift;

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct,
    });

    isa_ok(
        exception {
            $process->set_sku( 'nonsense' );
        },
        'XT::Exception::Data::Fulfilment::GOH::Integration::InvalidSkuBarcode',
        'Validate SKU to have correct barcode'
    );
}

sub move_items_from_missing_container :Tests {
    my $self = shift;

    note 'Get a DCD container at integration that is going to be treated as missing';
    my $missing_container_id = $self
        ->create_dcd_integration_container_to_be_integrated->container_id;

    note 'Create an container ID for empty container';
    my ($empty_container_id) = Test::XT::Data::Container->create_new_containers({
        status => $PUBLIC_CONTAINER_STATUS__AVAILABLE,
    });

    note 'Move content of missing container into empty one';
    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration
    });
    $process->transform_missing_container_into_empty({
        missing_container_id => NAP::DC::Barcode::Container::Tote->new_from_id($missing_container_id),
        empty_container_id   => $empty_container_id
    });

    note 'Do testing';
    my $integration_container_rs = $self->schema->resultset('Public::IntegrationContainer');

    my $missing_container_row = $integration_container_rs->search({
        container_id => $missing_container_id,
    })->first;
    my $empty_container_row = $integration_container_rs->search({
        container_id => $empty_container_id,
    })->first;

    is
        $empty_container_row->integration_container_items->count,
        1,
        'New tote has items from missing tote';

    is
        $empty_container_row->integration_container_items->filter_non_missing->count,
        0,
        'New tote has its items marked as Missing';

    is
        $missing_container_row->integration_container_items->count,
        0,
        'Missing tote does not have any items';

    ok
        $missing_container_row->is_complete,
        'Missing container is marked as complete';
}


sub remove_sku :Tests {
    my $self = shift;

    my $allocation_items_rs = $self
        ->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
            { items_quantity => 2 }
        )->allocation->allocation_items;

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_direct
    });

    subtest 'Try to remove SKU without having container' => sub {
        isa_ok(
            exception {
                # SKU does not matter as long as it has valid barcode
                $process->remove_sku_from_container( '123-321' );
            },
            'XT::Exception::Data::Fulfilment::GOH::Integration::NoIntegrationContainer',
            'Handle case with no container'
        );
    };

    my ($container) = Test::XT::Data::Container->create_new_container_rows;
    $process->set_container( $container->id );

    subtest 'Try to remove SKU from empty container' => sub {
        isa_ok(
            exception {
                # SKU does not matter as long as it has valid barcode
                $process->remove_sku_from_container( '123-321' );
            },
            'XT::Exception::Data::Fulfilment::GOH::Integration::ContainerIsEmpty',
            'Handle case with no container'
        );
    };

    note 'Add all SKUs into container';
    my @sku;
    foreach my $allocation_item ($allocation_items_rs->all) {
        my $sku = $allocation_item->shipment_item->get_sku;
        push @sku, $sku;
        $process->set_sku( $sku );
        $process->commit_scan;
    }

    subtest 'Try to use some non-sense rather than SKU' => sub {
        isa_ok(
            exception {
                $process->remove_sku_from_container( 'bla-bla-bla' );
            },
            'XT::Exception::Data::Fulfilment::GOH::Integration::InvalidSkuBarcode',
            'Invalid SKU barcode is detected'
        );
    };

    subtest 'Try to remove SKU that is not in container' => sub {
        $process->remove_sku_from_container( '123-321' );

        $process->integration_container_row->discard_changes;
        is
            $process->integration_container_row->integration_container_items->count,
            2,
            'Content of container was not changed';
    };

    subtest 'Remove first SKU from container' => sub {
        $process->remove_sku_from_container( shift @sku );

        $process->integration_container_row->discard_changes;
        is
            $process->integration_container_row->integration_container_items->count,
            1,
            'First item was successfully removed';
    };

    subtest 'Remove second SKU from container' => sub {

        my $shipment_item = $process->integration_container_row
            ->integration_container_items->first
            ->allocation_item
            ->shipment_item;

        ok
            $shipment_item->container_id,
            "Shipment item thinks it is in container";

        $process->remove_sku_from_container( shift @sku );

        $process->integration_container_row->discard_changes;
        is
            $process->integration_container_row->integration_container_items->count,
            0,
            'No more items in the container';

        ok
            !$self->schema->resultset('Public::IntegrationContainer')
                ->get_active_container_row( $container->id ),
            'No more record for container';

        $shipment_item->discard_changes;
        ok
            ! $shipment_item->container_id,
            "Shipment item does not believe it is in container anymore";
    };
}

sub multiple_goh_allocations_with_dcd :Tests {
    my $self = shift;

    note "Set up pack lanes so we have only one single tote and one multi-tote";
    my $plt = Test::XTracker::Data::PackRouteTests->new;
    $plt->reset_and_apply_config([
        {
            pack_lane_id  => 1,
            human_name    => 'pack_lane_1',
            capacity      => 1000,
            internal_name => 'DA.PO01.0000.CCTA01NP02',
            active        => 1,
            attributes    => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__SINGLE ]
        },
        {
            pack_lane_id  => 6,
            human_name    => 'multi_tote_pack_lane_1',
            capacity      => 1000,
            internal_name => 'DA.PO01.0000.CCTA01NP03',
            active        => 1,
            attributes    => [ $PACK_LANE_ATTRIBUTE__STANDARD, $PACK_LANE_ATTRIBUTE__MULTITOTE ]
        }
    ]);

    # put pack lanes back to the normal state afterwards
    my $plt_guard = guard {
        $plt->reset_and_apply_config($plt->like_live_packlane_configuration);
    };


    note "Create shipment with 2 GOH allocations and 1 DCD allocation";
    my $goh_prl_row = $self->schema->resultset("Public::Prl")->find($PRL__GOH);
    my $fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            Dematic => 1,
            GOH     => $goh_prl_row->max_allocation_items + 1, # Should be split into 2 GOH allocations
        },
    });

    note "Get both GOH allocations delivered, and the DCD allocation picked and on its way to integration";
    Test::XTracker::Data::Order->deliver_goh_allocations(
        $fixture->shipment_row,
        $PRL_DELIVERY_DESTINATION__GOH_INTEGRATION
    );

    my $dcd_allocation_row = $fixture->shipment_row->allocations->search({
        prl_id => $PRL__DEMATIC,
    })->first;
    my $dcd_allocation_item_row = $dcd_allocation_row->allocation_items->first;
    Test::XTracker::Data::Order->allocation_pick_complete($dcd_allocation_row);

    my ($dcd_container_row) = Test::XT::Data::Container->create_new_container_rows;
    my $integration_container = $self->schema
        ->resultset('Public::IntegrationContainer')
        ->create({
            container_id => $dcd_container_row->id,
            prl_id       => $PRL__GOH,
            from_prl_id  => $PRL__DEMATIC,
        });
    $dcd_allocation_item_row->add_to_integration_container({
        integration_container => $integration_container,
    });

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration
    });
    $process->set_container( $dcd_container_row->id );

    note "Put all the GOH items into the DCD container at integration";
    my $goh_allocations_rs = $fixture->shipment_row->allocations->search({
        prl_id => $PRL__GOH,
    });
    foreach my $goh_allocation_item_row ($goh_allocations_rs->related_resultset('allocation_items')->all) {
        $goh_allocation_item_row->add_to_integration_container({
            integration_container => $integration_container,
        });
    }

    note "Check that all items are in the correct container";
    foreach my $shipment_item_row ($fixture->shipment_row->shipment_items) {
        $shipment_item_row->discard_changes;
        is (
            $shipment_item_row->container_id, $dcd_container_row->id,
            sprintf("Shipment item [%d] is in correct container", $shipment_item_row->id)
        );
    }

    note "Complete the container and check it is sent to single tote pack lane";
    my $message_queue = Test::XTracker::MessageQueue->new;
    my $message_destination = config_var(PRL => 'conveyor_queue')
        or fail('Could not find queue in config');
    $message_queue->clear_destination($message_destination);

    note 'Mark GOH Integration container as completed';
    $process->mark_container_full({
        operator_id => $APPLICATION_OPERATOR_ID,
    });

    $message_queue->assert_messages(
        {
            destination  => $message_destination,
            assert_body => superhashof({
                '@type'      => 'route_request',
                container_id => $dcd_container_row->id->as_id,
                destination  => 'DA.PO01.0000.CCTA01NP02',
            }),
        },
        'route_request has been sent to single tote pack lane'
    );

}

=head2 prepare_different_mix_groups

Create commonly used data: one allocation with two items, one
allocation with one item and empty integration container.

Allocation's mix groups are different.

=cut

sub prepare_different_mix_groups {
    my $self = shift;

    note 'Create an allocation of two items';
    my ($allocation_item_1, $allocation_item_2)
        =
    $self->create_allocation_item_at_delivery_destination(
        $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
        { items_quantity => 2 }
    )->allocation->allocation_items->all;


    note 'Create an Integration container record';
    my ($container) =Test::XT::Data::Container->create_new_container_rows;
    my $integration_container = $self->schema
        ->resultset('Public::IntegrationContainer')
        ->create({
            container_id => $container->id,
            prl_id       => $PRL__GOH,
        });

    note 'Create another allocation with one item';
    my $allocation_item_3 =
        $self->create_allocation_item_at_delivery_destination(
            $PRL_DELIVERY_DESTINATION__GOH_DIRECT,
        )->allocation->allocation_items->first;

    isnt(
        $allocation_item_1->allocation->picking_mix_group,
        $allocation_item_3->allocation->picking_mix_group,
        'Make sure mix groups for allocatins are different'
    );

    return ($integration_container, $allocation_item_1,
        $allocation_item_2, $allocation_item_3);
}


sub goh_allocations_in_packing_list :Tests {
    my $self = shift;

    note "Create single-item GOH shipment and pick it";
    my $goh_prl_row = $self->schema->resultset("Public::Prl")->find($PRL__GOH);
    my $fixture = Test::XT::Fixture::Fulfilment::Shipment->new({
        prl_pid_counts => {
            GOH     => 1,
        },
    });

    Test::XTracker::Data::Order->pick_goh_shipment(
        $fixture->shipment_row,
    );
    my $shipment_id = $fixture->shipment_row->id;

    ok(
        !$self->is_in_packing_shipment_list($shipment_id),
        "shipment [$shipment_id] is not in packing list when allocation has been picked to hooks"
    );

    note "Get the GOH allocation delivered";
    Test::XTracker::Data::Order->deliver_goh_allocations(
        $fixture->shipment_row,
        $PRL_DELIVERY_DESTINATION__GOH_DIRECT
    );

    ok(
        !$self->is_in_packing_shipment_list($shipment_id),
        "shipment [$shipment_id] is still not in packing list after allocation has been delivered"
    );

    my ($container_row) = Test::XT::Data::Container->create_new_container_rows;
    my $integration_container = $self->schema
        ->resultset('Public::IntegrationContainer')
        ->create({
            container_id => $container_row->id,
            prl_id       => $PRL__GOH,
        });

    my $process = XT::Data::Fulfilment::GOH::Integration->new({
        $self->process_constructor_params_integration
    });
    $process->set_container( $container_row->id );

    note "Put the GOH item into the container at integration";
    my $goh_allocations_rs = $fixture->shipment_row->allocations->search({
        prl_id => $PRL__GOH,
    });
    foreach my $goh_allocation_item_row ($goh_allocations_rs->related_resultset('allocation_items')->all) {
        $goh_allocation_item_row->add_to_integration_container({
            integration_container => $integration_container,
        });
    }

    note 'Mark GOH Integration container as completed';
    $process->mark_container_full({
        operator_id => $APPLICATION_OPERATOR_ID,
    });

    ok(
        $self->is_in_packing_shipment_list($shipment_id),
        "after integration, shipment [$shipment_id] is in packing list"
    );
}

=head2 is_in_packing_shipment_list ($shipment_id) : boolean

Checks whether the provided shipment_id is contained in the (slightly
strangely arranged) data returned by get_packing_shipment_list. Returns
true if it is, false if it isn't.

=cut

sub is_in_packing_shipment_list {
    my $self = shift;
    my ($search_shipment_id) = @_;

    # get the data returned by get_packing_shipment_list and go through
    # it looking for our shipment
    my @shipment_lists = get_packing_shipment_list($self->schema->storage->dbh);
    # we get a set of lists, for normal shipments, staff, sample, rtv - go through each in turn
    foreach my $shipment_list (@shipment_lists) {
        # first level is split by channel
        foreach my $channel (keys %$shipment_list) {
            # then the keys are a string made of something related to sla plus shipment id
            foreach my $shipment_key (keys %{$shipment_list->{$channel}}) {
                # the actual thing we're looking for is the shipment id
                return 1 if ($shipment_list->{$channel}->{$shipment_key}->{shipment_id} == $search_shipment_id);
            }
        }
    }
    return 0;
}
