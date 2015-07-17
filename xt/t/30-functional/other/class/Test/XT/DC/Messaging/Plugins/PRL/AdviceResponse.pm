package Test::XT::DC::Messaging::Plugins::PRL::AdviceResponse;

=head1 NAME

Test::XT::DC::Messaging::Plugins::PRL::AdviceResponse - Unit tests for XT::DC::Messaging::Plugins::PRL::AdviceResponse

=head1 DESCRIPTION

Unit tests for XT::DC::Messaging::Plugins::PRL::AdviceResponse

=head1 NOTES

Be aware that the $product variable used throughout is not only a
product, it's a hashref containing:

    * product => XTracker::Schema::Result::Public::Product
    * group_id/recode_id => 123
    * sku => '456-789'
    * variant_id => 1234

Test::XT::Data::PutawayPrep->create_product_and_stock_process,
which is called for almost every test, creates a stock_process with quantity 10.

For the recode tests, it's hard-coded to recode 10 SKUs into 17 new SKUs.

#TAGS shouldbeunit goodsin putaway putawayprep loops

=head1 SEE ALSO

L<putaway.t>

=head1 METHODS

=cut

use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::GoodsIn::PutawayPrep";
};

use Test::More::Prefix qw/ test_prefix /;

use MooseX::Params::Validate qw/validated_list/;

use Test::XTracker::RunCondition prl_phase => 'prl';
use Test::XTracker::Data; # get_schema
use Test::XT::Data::PutawayPrep qw/
    create_product_and_stock_process
    create_pp_group
    create_pp_container
/;
use Test::XT::Data::Container;

use XTracker::Database::StockProcess qw/putaway_completed/;
use XTracker::Constants qw/:application :prl_type/;
use XTracker::Constants::FromDB qw/
    :container_status
    :putaway_prep_group_status
    :putaway_prep_container_status
    :stock_process_status
    :delivery_action
    :shipment_item_status
/;
use XTracker::Database::PutawayPrep::RecodeBased;
use XTracker::Database::PutawayPrep;
use XTracker::Database::PutawayPrep::CancelledGroup;
use XTracker::Database::PutawayPrep::MigrationGroup;
use XT::Domain::PRLs;
use Data::Dumper;

sub setup : Tests(setup => 1) {
    my ($self) = @_;

    # generate a stock process group with pgid, variants, etc.
    $self->{setup} = Test::XT::Data::PutawayPrep->new;

    $self->{pp_container_rs} = $self->schema->resultset('Public::PutawayPrepContainer');

    $self->{pp_helper}
        = XTracker::Database::PutawayPrep->new;
    $self->{pp_recode_helper}
        = XTracker::Database::PutawayPrep::RecodeBased->new;
    $self->{pp_cancelled_helper}
        = XTracker::Database::PutawayPrep::CancelledGroup->new;
    $self->{pp_migration_helper}
        = XTracker::Database::PutawayPrep::MigrationGroup->new;

    $self->{PRL_NAME} = 'Full PRL'; # an example of one PRL
}

sub teardown : Tests(teardown) {
    my ($self) = @_;
}

=head2 container_failure

=cut

sub container_failure : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
        {
            test_type => 'stock from cancelled group',
            pp_helper => $self->{pp_cancelled_helper},
        },
        {
            test_type => 'stock from migration group',
            pp_helper => $self->{pp_migration_helper},
        },
    ) {
        note("set up ".$config->{test_type});
        my $pp_helper = $config->{pp_helper};

        my ($process_data, $product_data)
            = $self->{setup}->create_product_and_stock_process(1, { group_type => $pp_helper->name });
        my $group_id = $product_data->{ $pp_helper->container_group_field_name };

        note $pp_helper->container_group_field_name;
        note $product_data->{ $pp_helper->container_group_field_name };

        note("start a container");
        my $pp_container = $self->{setup}->create_pp_container();
        my $container_id = $pp_container->container_id;
        my $pp_group = $self->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $pp_helper->name,
        });

        # We should complain when we can't find a matching 'IN TRANSIT' container
        throws_ok( sub {
            $self->fake_advice_response(
                response     => $PRL_TYPE__BOOLEAN__FALSE,
                container_id => 'M98765432123456789',
                reason       => 'Frobnitz in the super cooler',
                may_die      => 1,
            ) },
            qr/Can't find an appropriate PutawayPrepContainer record for container 'M98765432123456789'/,
            "Throws when we can't find a matching PutawayPrepContainer - bad container id"
        );

        # If we get an advice response before we've sent an advice, it should die
        throws_ok( sub {
            $self->fake_advice_response(
                response     => $PRL_TYPE__BOOLEAN__FALSE,
                container_id => $container_id,
                reason       => 'Frobnitz in the super cooler',
                may_die      => 1,
            ) },
            qr/Can't find an appropriate PutawayPrepContainer record for container '$container_id'/,
            "Throws when we can't find a matching PutawayPrepContainer - bad container status"
        );

        # Pretend we've sent an advice message - update the status to In Transit
        $pp_container->update({
            putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT
        });

        # The real message with our actual container - now it should work
        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__FALSE,
            container_id => $container_id,
            reason       => 'Frobnitz in the super cooler',
            may_die      => 1,
        );

        # Get rid of cached version
        $pp_container->discard_changes;

        # Update the modified time
        isnt( $pp_container->modified, '2000-01-01 00:00:00',
            "Modified has been updated" );

        # Update the container status
        is( $pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__FAILURE,
            "PP Container Status now Failure" );

        # Reason on container
        is( $pp_container->failure_reason, "Frobnitz in the super cooler",
            "Reason set correctly");

        if ( $pp_helper->name eq XTracker::Database::PutawayPrep::RecodeBased->name) {
            ok( ! $process_data->complete, 'Stock Recode is correctly not completed' );
        } elsif ( $pp_helper->name eq XTracker::Database::PutawayPrep->name) {
            is( $self->schema->resultset('Public::Putaway')->find({
                stock_process_id => $process_data->id
            }), undef, 'nothing was putaway');
        } elsif ( $pp_helper->name eq XTracker::Database::PutawayPrep::CancelledGroup->name) {
            is(
                $product_data->{shipment_row}->shipment_items->first->shipment_item_status_id,
                $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
                'Shipment items for correspondent SKU stays in the CANCEL_PENDING status'
            );
        }
    } # test configs

}

=head2 order_of_3_items_of_the_same_sku_and_only_2_putaway

=cut

sub order_of_3_items_of_the_same_sku_and_only_2_putaway :Tests {
    my ($self) = @_;

    my $pp_helper = $self->{pp_cancelled_helper};
    my $pp_container_rs = $self->{pp_container_rs};

    note 'Create cancelled shipment with three items (of the same SKU)';
    my ($stock_process, $product)
        = $self->{setup}->create_product_and_stock_process(3, {
            group_type => $pp_helper->name,
        });
    my $group_id = $product->{ $pp_helper->container_group_field_name };


    note("Start a container");
    my $pp_container = $self->{setup}->create_pp_container();

    note("Add only two items to the container");
    $pp_container_rs->add_sku({
        container_id => $pp_container->container_id,
        group_id     => $group_id,
        sku          => $product->{sku},
        putaway_prep => $pp_helper,
    }) for 1..2;


    note 'Finish the container';
    $pp_container_rs->finish({ container_id => $pp_container->container_id });

    note 'Send advice response from PRL to XT';
    $self->fake_advice_response(
        response     => $PRL_TYPE__BOOLEAN__TRUE,
        container_id => $pp_container->container_id,
    );

    # make sure all data in memory is synchronized with database
    $_->discard_changes for $pp_container, $product->{shipment_row};

    is(
        $pp_container->status_id,
        $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
        "PP Container Status now Complete"
    );

    my @shipment_items = $product->{shipment_row}->shipment_items->all;

    is(scalar(@shipment_items), 3, 'Order has three items');
    is(
        $shipment_items[0]->variant->sku,
        $shipment_items[1]->variant->sku,
        'Borth 1st and 2nd items refer to the same SKU'
    );
    is(
        $shipment_items[1]->variant->sku,
        $shipment_items[2]->variant->sku,
        'Borth 2nd and 3d items refer to the same SKU'
    );
    is(
        scalar(grep { $_->shipment_item_status_id eq $SHIPMENT_ITEM_STATUS__CANCELLED} @shipment_items),
        2,
        'Two shipment item moved to CANCELLED status'
    );
    is(
        scalar(grep { $_->shipment_item_status_id eq $SHIPMENT_ITEM_STATUS__CANCEL_PENDING} @shipment_items),
        1,
        'Another shipment item stays in the CANCEL PENDING status'
    );
    @shipment_items = sort { $b->id <=> $a->id } @shipment_items;
    is(
        $shipment_items[0]->shipment_item_status_id,
        $SHIPMENT_ITEM_STATUS__CANCEL_PENDING,
        'Shipment item created at the very last left in CANCEL PENDING status'
    );
}

=head2 container_success

=cut

sub container_success : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
        {
            test_type => 'stock from cancelled group',
            pp_helper => $self->{pp_cancelled_helper},
        },
        {
            test_type => 'stock from migrated group',
            pp_helper => $self->{pp_migration_helper},
        },
    ) {
        note("set up ".$config->{test_type});
        my $pp_helper = $config->{pp_helper};
        my $pp_container_rs = $self->{pp_container_rs};

        my ($stock_process, $product)
            = $self->{setup}->create_product_and_stock_process(1, {
                group_type => $pp_helper->name,
            });
        my $group_id = $product->{ $pp_helper->container_group_field_name };

        note("start a container");
        my $pp_container = $self->{setup}->create_pp_container();
        my $pp_group = $pp_helper->get_or_create_putaway_prep_group({ group_id => $group_id });

        note("add all items to the container");
        $pp_container_rs->add_sku({
            container_id => $pp_container->container_id,
            group_id     => $group_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. $stock_process->quantity;

        my $log_delivery_quantity = $stock_process->quantity;

        my $prl_location = $self->schema->resultset('Public::Location')->single({
            location => $self->{PRL_NAME}
        });
        ok( $prl_location, $self->{PRL_NAME} ." exists as a location" );

        # set an old date, so we can check it's been changed below
        $pp_container->update({ modified => '2000-01-01 00:00:00' });

        # finish the container
        $pp_container_rs->finish({ container_id => $pp_container->container_id });

        if ($config->{test_type} eq 'stock process') {
            $self->expect_log_delivery_row(
                [ $stock_process->delivery_item->delivery_id ],
                $log_delivery_quantity
            );
        }

        my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new('xt_to_prls');

        # send advice response from PRL to XT
        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container->container_id,
        );

        # if this was for migration, we should've sent one container_empty to
        # full prl only
        if ($config->{test_type} eq 'stock from migrated group') {
            my $full_prl = XT::Domain::PRLs::get_prl_from_name({
                prl_name => 'Full',
            });
            $xt_to_prls->expect_messages({
                messages => [{
                    'type'    => 'container_empty',
                    'path'    => $full_prl->amq_queue,
                    'details' => {
                        container_id => $pp_container->container_id,
                    },
                }],
            });
        } else {
            $xt_to_prls->expect_no_messages;
        }

        $pp_container->discard_changes;
        isnt( $pp_container->modified, '2000-01-01 00:00:00', "Modified has been updated" );

        is( $pp_container->status_id,
            $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
            "PP Container Status now Complete"
        );

        # Failure reason shouldn't be set
        is( $pp_container->failure_reason, undef, "Reason remains unset" );

        $self->is_putaway(
            group_type       => $pp_helper->name,
            product_data     => $product,
            process_data     => $stock_process,
            quantity_expected=> $stock_process->quantity,
        );

    } # test configs
}

=head2 fail_on_invalid_group_status

=cut

sub fail_on_invalid_group_status : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
        {
            test_type => 'stock from cancelled group',
            pp_helper => $self->{pp_cancelled_helper},
        },
        {
            test_type => 'stock from migrated group',
            pp_helper => $self->{pp_migration_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        my ( $stock_process, $pp_container, $pp_group )
            = $self->create_product_stock_process_container(
                test_summary    => "add all items to first container",
                sku_difference  => 0,
                pp_helper       => $config->{pp_helper},
            );

        note("Set the Group status to COMPLETED, so it's invalid to get another AdviceResponse for it");
        $pp_group->update({ status_id => $PUTAWAY_PREP_GROUP_STATUS__COMPLETED });

        throws_ok(
            sub {
                $self->fake_advice_response(
                    response     => $PRL_TYPE__BOOLEAN__TRUE,
                    container_id => $pp_container->container_id,
                    may_die      => 1,
                );
            },
            qr/pp_group \d+ is not active/,
            'Unexpected AdviceResponse is detected'
        );
    } # test configs
}

=head2 two_groups_one_container_completed

=cut

sub two_groups_one_container_completed : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
        {
            test_type => 'stock from migrated group',
            pp_helper => $self->{pp_migration_helper},
        },
    ) {
        test_prefix($config->{test_type});
        note "set up " . $config->{test_type};

        my $pp_helper = $config->{pp_helper};

        my ($stock_process, $product)
             = $self->{setup}->create_product_and_stock_process(1, { group_type => $pp_helper->name });
        my $group_id = $product->{ $pp_helper->container_group_field_name };

        note("start a container");
        my $pp_container = $self->{setup}->create_pp_container(1);
        my $pp_group = $self->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $pp_helper->name,
        });

        note("add all items to the container");
        $self->{pp_container_rs}->add_sku({
            container_id => $pp_container->container_id,
            group_id     => $group_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. $stock_process->quantity;

        note "set up another " . $config->{test_type};
        my ($stock_process2, $product2)
             = $self->{setup}->create_product_and_stock_process(1, { group_type => $pp_helper->name });
        my $group_id2 = $product2->{ $pp_helper->container_group_field_name };
        my $pp_group2 = $self->{setup}->create_pp_group({
            group_id   => $group_id2,
            group_type => $pp_helper->name,
        });

        note("add all items to same container");
        $self->{pp_container_rs}->add_sku({
            container_id => $pp_container->container_id,
            group_id     => $group_id2,
            sku          => $product2->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. $stock_process2->quantity;

        # Every item in both deliveries into one container
        my $quantity_expected_in_delivery_log = $stock_process->quantity + $stock_process2->quantity;

        note("finish putaway prep container");
        $self->{pp_container_rs}->finish({ container_id => $pp_container->container_id });

        if ($config->{test_type} eq 'stock_process') {
            $self->expect_log_delivery_row(
                [ ($stock_process->delivery_item->delivery_id, $stock_process2->delivery_item->delivery_id) ],
                $quantity_expected_in_delivery_log
            );
        }

        $pp_container->discard_changes;
        is($pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT, 'container is in transit');

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container->container_id,
        );

        $_->discard_changes for $pp_container, $pp_group, $pp_group2;
        is($pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'container is completed');
        is($pp_group->status_id,     $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,    'first group is completed');
        is($pp_group2->status_id,    $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,    'second group is completed');

        note("first ".$config->{test_type}." should be putaway");
        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity,
        );
        note("second ".$config->{test_type}." should be putaway");
        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product2,
            process_data      => $stock_process2,
            quantity_expected => $stock_process2->quantity,
        );
        $self->test_discrepancies($config, "First Container",  $stock_process,  0);
        $self->test_discrepancies($config, "Second Container", $stock_process2, 0);
    } # test configs
    test_prefix("");
}

=head2 two_groups_one_container_problem_first_container

=cut

sub two_groups_one_container_problem_first_container : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        my $pp_helper = $config->{pp_helper};
        my ($stock_process, $product)
            = $self->{setup}->create_product_and_stock_process(1, { group_type => $pp_helper->name });
        my $group_id = $product->{ $pp_helper->container_group_field_name };

        note("start a container");
        my $pp_container = $self->{setup}->create_pp_container(1);
        my $pp_group = $self->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $pp_helper->name,
        });

        note("add too many items to the container");
        $self->{pp_container_rs}->add_sku({
            container_id => $pp_container->container_id,
            group_id     => $group_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. $stock_process->quantity + 1;

        note("set up another ".$config->{test_type});
        my ($stock_process2, $product2)
            = $self->{setup}->create_product_and_stock_process(1, {group_type => $pp_helper->name });
        my $group_id2 = $product2->{ $pp_helper->container_group_field_name };
        my $pp_group2 = $self->{setup}->create_pp_group({
            group_id   => $group_id2,
            group_type => $pp_helper->name,
        });

        note("add all items to same container");
        $self->{pp_container_rs}->add_sku({
            group_id     => $group_id2,
            container_id => $pp_container->container_id,
            sku          => $product2->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. $stock_process->quantity;

        note("finish putaway prep container");
        $self->{pp_container_rs}->finish({ container_id => $pp_container->container_id });

        $pp_container->discard_changes;
        is($pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT, 'container is in transit');

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container->container_id,
        );

        $_->discard_changes for $pp_container, $pp_group, $pp_group2;
        is($pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'container is completed');
        is($pp_group->status_id,     $PUTAWAY_PREP_GROUP_STATUS__PROBLEM,      'first group problem detected');
        is($pp_group2->status_id,    $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,    'second group is completed');

        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity + 1,
        );
        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product2,
            process_data      => $stock_process2,
            quantity_expected => $stock_process2->quantity,
        );
    } # test configs
}

=head2 two_groups_one_container_problem_second_container

=cut

sub two_groups_one_container_problem_second_container : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
    ) {
        test_prefix($config->{test_type});
        note("set up ".$config->{test_type});

        my $pp_helper = $config->{pp_helper};
        my ($stock_process, $product)
            = $self->{setup}->create_product_and_stock_process(1, { group_type => $pp_helper->name });
        my $group_id = $product->{ $pp_helper->container_group_field_name };

        note("start a container");
        my $pp_container = $self->{setup}->create_pp_container(1);
        my $pp_group = $self->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $pp_helper->name,
        });

        note("add all items to the container");
        $self->{pp_container_rs}->add_sku({
            group_id     => $group_id,
            container_id => $pp_container->container_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. $stock_process->quantity;

        note("set up another stock process");
        my ($stock_process2, $product2)
            = $self->{setup}->create_product_and_stock_process(1, { group_type => $pp_helper->name });
        my $group_id2 = $product2->{ $pp_helper->container_group_field_name };
        my $pp_group2 = $self->{setup}->create_pp_group({
            group_id   => $group_id2,
            group_type => $pp_helper->name,
        });

        note("add too many items to same container");
        $self->{pp_container_rs}->add_sku({
            group_id     => $group_id2,
            container_id => $pp_container->container_id,
            sku          => $product2->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. $stock_process->quantity + 1;

        note("finish putaway prep container");
        $self->{pp_container_rs}->finish({ container_id => $pp_container->container_id });
        $pp_container->discard_changes;

        is($pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT, 'container is in transit');

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container->container_id,
        );

        $_->discard_changes for $pp_container, $pp_group, $pp_group2;

        is($pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'container is completed');
        is($pp_group->status_id,     $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,    'first group is completed');
        is($pp_group2->status_id,    $PUTAWAY_PREP_GROUP_STATUS__PROBLEM,      'second group problem detected');

        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity,
        );
        $self->test_discrepancies(
            $config,
            "First Container, without discrepancy",
            $stock_process,
            0,
        );

        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product2,
            process_data      => $stock_process2,
            quantity_expected => $stock_process2->quantity + 1,
        );
        $self->test_discrepancies(
            $config,
            "Second Container, with discrepancy",
            $stock_process2,
            1,
        );
    } # test configs
    test_prefix("");
}

=head2 one_group_one_container_completed

=cut

sub one_group_one_container_completed : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
        {
            test_type => 'stock from cancelled group',
            pp_helper => $self->{pp_cancelled_helper},
        },
        {
            test_type => 'stock from migrated group',
            pp_helper => $self->{pp_migration_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        my ( $stock_process, $pp_container, $pp_group, $product )
            = $self->create_product_stock_process_container(
                test_summary   => "add all items to first container",
                sku_difference => 0,
                pp_helper      => $config->{pp_helper},
            );

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container->container_id,
        );

        $_->discard_changes for $pp_container, $pp_group;

        is($pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'container is completed');
        is($pp_group->status_id,     $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,    'group is completed');

        $self->is_putaway(
            group_type        => $config->{pp_helper}->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity,
        );
    } # test configs

}

=head2 one_group_one_container_problem

=cut

sub one_group_one_container_problem : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
        # there is no need to have similar test for CancelledGroup because
        # we do expect as many items for such pp_group as it was scanned into it
    ) {
        test_prefix($config->{test_type});
        note("set up ".$config->{test_type});

        my ( $stock_process, $pp_container, $pp_group, $product )
            = $self->create_product_stock_process_container(
                test_summary   => "add 1 too many items to first container",
                sku_difference => 1,
                pp_helper      => $config->{pp_helper},
            );

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container->container_id,
        );

        $_->discard_changes for $pp_container, $pp_group;

        is($pp_container->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'container is completed');
        is($pp_group->status_id,     $PUTAWAY_PREP_GROUP_STATUS__PROBLEM,      'group problem is detected');

        $self->is_putaway(
            group_type        => $config->{pp_helper}->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity + 1,
        );
        $self->test_discrepancies(
            $config,
            "Container with discrepancy",
            $stock_process,
            1,
        );
    } # test configs
    test_prefix("");
}

=head2 one_group_two_containers_completed

=cut

sub one_group_two_containers_completed : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
    ) {
        test_prefix($config->{test_type});
        note("set up ".$config->{test_type});

        my $pp_helper = $config->{pp_helper};
        my ( $stock_process, $pp_container1, $pp_group, $product, $group_id )
            = $self->create_product_stock_process_container(
                test_summary   => "add all but 5 items to first container",
                sku_difference => -5,
                pp_helper      => $pp_helper,
            );

        my $log_delivery_quantity = 5; # sku difference causes 5 items to go into a container

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container1->container_id,
        );

        $_->discard_changes for $pp_container1, $pp_group;
        is(
            $pp_container1->status_id,
            $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
            'container is completed',
        );
        is(
            $pp_group->status_id,
            $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
            'group is still in progress',
        );
        $self->test_discrepancies($config, "First Container", $stock_process, 0);

        note("start a second container");
        my $pp_container2 = $self->{setup}->create_pp_container();

        note("add remaining 5 items to second container");
        $self->{pp_container_rs}->add_sku({
            group_id     => $group_id,
            container_id => $pp_container2->container_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. 5;

        $log_delivery_quantity += 5;

        note("finish putaway prep for second container");
        $self->{pp_container_rs}->finish({ container_id => $pp_container2->container_id });

        if ($config->{test_type} eq 'stock_process') {
            $self->expect_log_delivery_row(
                [ $stock_process->delivery_item->delivery_id ],
                $log_delivery_quantity
            );
        }

        $pp_container2->discard_changes;
        is($pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT, 'second container is in transit');

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container2->container_id,
        );

        $_->discard_changes for $pp_container2, $pp_group;
        is($pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'second container is completed');
        is($pp_group->status_id,      $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,    'group is completed');

        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity,
        );

        $self->test_discrepancies($config, "Second Container", $stock_process, 0);
    } # test configs
    test_prefix("");
}

sub test_discrepancies {
    my ($self, $config, $description, $stock_process_row, $expected_discrepancy_count) = @_;
    $config->{test_type} eq 'stock_process' or return;

    note "Discrepancies: $description";

    my $discrepancy_rs = $self->schema->resultset('Public::LogPutawayDiscrepancy');
    my $discrepancy_count = $discrepancy_rs->search({
        stock_process_id => $stock_process_row->id,
    })->count;

    is(
        $discrepancy_count,
        $expected_discrepancy_count,
        "$expected_discrepancy_count expected discrepancies for the StockProcess (" . $stock_process_row->id . ")",
    );
}

=head2 one_group_two_containers_simultaneously

=cut

sub one_group_two_containers_simultaneously : Tests {
    my ($self) = @_;

    # This is designed to test the "Are all containers complete?" part
    # i.e. having two containers in progress when an AdviceResponse arrives

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        my $pp_helper = $config->{pp_helper};
        my ($stock_process, $product)
            = $self->{setup}->create_product_and_stock_process(1, { group_type => $pp_helper->name });
        my $group_id = $product->{ $pp_helper->container_group_field_name };

        note("start a container");
        my $pp_container1 = $self->{setup}->create_pp_container(1);
        my $pp_group = $self->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $pp_helper->name,
        });

        note("add all but 5 items to first container");
        $self->{pp_container_rs}->add_sku({
            group_id     => $group_id,
            container_id => $pp_container1->container_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. ($stock_process->quantity - 5);

        note("finish putaway prep for first container");
        $self->{pp_container_rs}->finish({ container_id => $pp_container1->container_id });
        $pp_container1->discard_changes;
        is($pp_container1->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT, 'container is in transit');

        note("do not send advice response yet");

        note("start a second container");
        my $pp_container2 = $self->{setup}->create_pp_container(1);

        note("add remaining 5 items to second container");
        $self->{pp_container_rs}->add_sku({
            group_id     => $group_id,
            container_id => $pp_container2->container_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. 5;

        note("finish putaway prep for second container");
        $self->{pp_container_rs}->finish({ container_id => $pp_container2->container_id });
        $pp_container2->discard_changes;
        is($pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT, 'second container is in transit');

        note("first container response");
        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container1->container_id,
        );

        $_->discard_changes for $pp_container1, $pp_group;
        is($pp_container1->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'container is completed');
        is($pp_group->status_id,      $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,  'group is still in progress');

        note("second container response");
        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container2->container_id,
        );

        $_->discard_changes for $pp_container2, $pp_group;
        is($pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'second container is completed');
        is($pp_group->status_id,      $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,    'group is completed');

        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity,
        );
    } # test configs
}

=head2 one_group_two_containers_surplus_first_container

=cut

sub one_group_two_containers_surplus_first_container : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        my $pp_helper = $config->{pp_helper};
        my ( $stock_process, $pp_container1, $pp_group, $product, $group_id )
            = $self->create_product_stock_process_container(
                test_summary   => "add 1 too many items to first container",
                sku_difference => 1,
                pp_helper      => $pp_helper,
            );

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container1->container_id,
        );

        $_->discard_changes for $pp_container1, $pp_group, $stock_process;
        is($pp_container1->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'container is completed');
        is($pp_group->status_id,      $PUTAWAY_PREP_GROUP_STATUS__PROBLEM,      'group problem is detected');

        # we will check the putaway status once and for all, at the end of the test

        note("start a second container");
        my $pp_container2 = $self->{setup}->create_pp_container();

        note("add 1 more item to second container");
        $self->{pp_container_rs}->add_sku({
            group_id     => $group_id,
            container_id => $pp_container2->container_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        });

        note("finish putaway prep for second container");
        $self->{pp_container_rs}->finish({ container_id => $pp_container2->container_id });
        $pp_container2->discard_changes;
        is($pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT, 'second container is in transit');

        # PRL still doesn't know anything might be wrong, so accepts the advice
        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container2->container_id,
        );

        $_->discard_changes for $pp_container2, $pp_group;
        is($pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'second container is completed');
        is($pp_group->status_id,      $PUTAWAY_PREP_GROUP_STATUS__PROBLEM,      'group problem remains detected');

        note('both containers should be putaway, with a surplus of 2 (1 extra from the first container, then another 1 in the second)');
        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity + 2,
        );
    } # test configs
}

=head2 one_group_two_containers_surplus_second_container

=cut

sub one_group_two_containers_surplus_second_container : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            pp_helper => $self->{pp_helper},
        },
        {
            test_type => 'stock recode',
            pp_helper => $self->{pp_recode_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        my $pp_helper = $config->{pp_helper};
        my ( $stock_process, $pp_container1, $pp_group, $product, $group_id )
            = $self->create_product_stock_process_container(
                test_summary   => "add all but 5 items to first container",
                sku_difference => -5,
                pp_helper      => $pp_helper,
            );

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container1->container_id,
        );

        $_->discard_changes for $pp_container1, $pp_group;
        is($pp_container1->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'container is completed');
        is($pp_group->status_id,      $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,  'group is still in progress');

        note("start a second container");
        my $pp_container2 = $self->{setup}->create_pp_container();

        note("add remaining 5 items plus 1 more to second container");
        $self->{pp_container_rs}->add_sku({
            group_id     => $group_id,
            container_id => $pp_container2->container_id,
            sku          => $product->{sku},
            putaway_prep => $pp_helper,
        }) for 1 .. 6;

        note("finish putaway prep for second container");
        $self->{pp_container_rs}->finish({ container_id => $pp_container2->container_id });
        $pp_container2->discard_changes;
        is($pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT, 'second container is in transit');

        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__TRUE,
            container_id => $pp_container2->container_id,
        );

        $_->discard_changes for $pp_container2, $pp_group;
        is($pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE, 'second container is completed');
        is($pp_group->status_id,      $PUTAWAY_PREP_GROUP_STATUS__PROBLEM,      'group problem is detected');

        $self->is_putaway(
            group_type        => $pp_helper->name,
            product_data      => $product,
            process_data      => $stock_process,
            quantity_expected => $stock_process->quantity + 1,
        );
    } # test configs
}

# HELPER METHODS

sub create_product_stock_process_container {
    my ($self, $test_summary, $sku_difference, $pp_helper) = validated_list(
        \@_,
        test_summary   => { isa => 'Str'},
        sku_difference => { isa => 'Int'},
        pp_helper      => { isa => 'XTracker::Database::PutawayPrep' }
    );

    note(sprintf 'set up stock process for %s', $pp_helper->name);

    my ($stock_process, $product)
        = $self->{setup}->create_product_and_stock_process(1, {
            group_type => $pp_helper->name,
        });
    my $group_id = $product->{ $pp_helper->container_group_field_name };

    note("start a container");
    my $pp_container1 = $self->{setup}->create_pp_container();
    my $pp_group = $self->{setup}->create_pp_group({
        group_id   => $group_id,
        group_type => $pp_helper->name,
    });

    note($test_summary);
    # default $sku_count will be 10 for stock_process, and 17 for stock_recode
    my $sku_count = $stock_process->quantity + $sku_difference;
    note("Add $sku_count skus to the container");

    $self->{pp_container_rs}->add_sku({
        group_id     => $group_id,
        container_id => $pp_container1->container_id,
        sku          => $product->{sku},
        putaway_prep => $pp_helper,
    }) for 1 .. $sku_count;

    note("finish putaway prep for first container");
    $self->{pp_container_rs}->finish({ container_id => $pp_container1->container_id });
    $pp_container1->discard_changes;
    is(
        $pp_container1->status_id,
        $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
        'container is in transit',
    );

    return( $stock_process, $pp_container1, $pp_group, $product, $group_id );
}

sub is_putaway {
    my ($self, $product_data, $stock_process_row, $quantity_expected, $group_type ) = validated_list(
        \@_,
        product_data      => { isa => 'HashRef' },
        process_data      => { isa => 'Any' },
        quantity_expected => { isa => 'Maybe[Int]' },
        group_type        => { isa => 'Str', optional => 1 },
    );

    $group_type ||= XTracker::Database::PutawayPrep->name;

    $_->discard_changes for grep {ref} $stock_process_row, $product_data->{product};

    if ($group_type eq XTracker::Database::PutawayPrep::RecodeBased->name) {

        # Stock recode status
        ok( $stock_process_row->complete, 'Stock Recode is complete' );

        # copied and pasted from recode_iws.t
        # the first snapshot was taken in Test::XT::Data::PutawayPrep
        # this takes another snapshot and compares with the first
        my @in_quantity_tests = @{$product_data->{in_quantity_tests}};
        my @out_quantity_tests = @{$product_data->{out_quantity_tests}};

        $_->snapshot('after recode putaway') for @out_quantity_tests, @in_quantity_tests;

        $_->test_delta(
            from         => 'after recode destroy',
            to           => 'after recode putaway',
            stock_status => {
                'Main Stock' => $stock_process_row->quantity,
            },
        ) for @in_quantity_tests;

        $_->test_delta(
            from         => 'after recode destroy',
            to           => 'after recode putaway',
            stock_status => {},
        ) for @out_quantity_tests;

        like( $stock_process_row->notes, qr/^Putaway/, 'stock recode was putaway' );

    } elsif ($group_type eq XTracker::Database::PutawayPrep->name) {

        # Stock process status
        is(
            $stock_process_row->status_id,
            $STOCK_PROCESS_STATUS__PUTAWAY,
            'Stock process status is Putaway'
        );

        # Putaway complete?
        is(
            putaway_completed( $self->schema->storage->dbh, $stock_process_row->id),
            1,
            'Putaway is completed'
        );

        is(
            $self->schema->resultset('Public::Putaway')
                ->find({ stock_process_id => $stock_process_row->id })->quantity,
            $quantity_expected,
            'correct quantity was putaway'
        );
    } elsif ($group_type eq XTracker::Database::PutawayPrep::CancelledGroup->name) {
        is(
            $product_data->{shipment_row}->shipment_items->first->shipment_item_status_id,
            $SHIPMENT_ITEM_STATUS__CANCELLED,
            'Shipment items for correspondent SKU moves to CANCELLED status'
        );
    }
}

sub expect_log_delivery_row {
    my ($self, $delivery_ids, $total_quantity_expected) = @_;

    my $quantity = $self->schema->resultset('Public::LogDelivery')->search({
        delivery_id => $delivery_ids,
        delivery_action_id => $DELIVERY_ACTION__PUTAWAY_PREP
    })->get_column('quantity')->func('SUM');

    note("Quantity recorded as putaway in delivery row: $quantity (comparing to $total_quantity_expected)");

    is($quantity, $total_quantity_expected, "Log Delivery table contains quantity expected for deliveries: ". join($delivery_ids));

}

1;
