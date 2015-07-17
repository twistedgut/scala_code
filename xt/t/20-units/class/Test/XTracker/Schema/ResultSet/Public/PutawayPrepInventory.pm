package Test::XTracker::Schema::ResultSet::Public::PutawayPrepInventory;

use NAP::policy "tt", 'test', 'class';
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends 'NAP::Test::Class';
    with 'NAP::Test::Class::Template', 'Test::Role::GoodsIn::PutawayPrep';
};

use Test::XTracker::RunCondition prl_phase => 'prl';


use Test::Exception; # lives_ok

use Test::XT::Data::PutawayPrep;
use XTracker::Database::PutawayPrep;
use XTracker::Database::PutawayPrep::RecodeBased;
use XTracker::Constants qw(
    $APPLICATION_OPERATOR_ID
    :prl_type
);

sub startup :Test(startup => 8) {
    my ($self) = @_;
    $self->SUPER::startup();

    $self->{pp_container_rs}  = $self->schema->resultset('Public::PutawayPrepContainer');
    $self->{pp_helper}        = XTracker::Database::PutawayPrep->new({ schema => $self->schema });
    $self->{pp_recode_helper} = XTracker::Database::PutawayPrep::RecodeBased->new({ schema => $self->schema });
    $self->{setup}            = Test::XT::Data::PutawayPrep->new;
}

# TESTS

sub create_inventory_items : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            test_type           => 'normal',
            voucher             => 0,
            variant_table       => 'Public::Variant',
            group_id_field_name => 'pgid',
            pp_helper           => $self->{pp_helper}
        },
        {
            test_type           => 'voucher',
            voucher             => 1,
            variant_table       => 'Voucher::Variant',
            group_id_field_name => 'pgid',
            pp_helper           => $self->{pp_helper}
        },
    ) {
        my ($stock_process, $product_data)
            = $self->{setup}->create_product_and_stock_process(1,
                { voucher => $config->{voucher} });
        my $group_id = $product_data->{ $config->{group_id_field_name} };
        my $sku      = $product_data->{sku};
        my $pp_group = $self->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $config->{pp_helper}->name,
        });
        my $pp_container = $self->{setup}->create_pp_container;

        # verify variant exists in its own table
        ok(
            $self->schema->resultset( $config->{variant_table} )
                ->find($product_data->{variant_id}),
            $config->{test_type}.' variant was created in correct table'
        );

        note("adding SKU $sku to container");
        $self->{pp_container_rs}->add_sku({
            container_id => $pp_container->container_id,
            sku          => $sku,
            putaway_prep => $config->{pp_helper},
            group_id     => $group_id,
        });

        # verify pp_inventory item can be found independently
        my $inventory_item;
        lives_ok( sub {
            $inventory_item = $self->schema->resultset('Public::PutawayPrepInventory')
                ->search_with_variant({
                    putaway_prep_container_id => $pp_container->id,
                    pgid                      => $pp_group->group_id, # might actually be an rgid (recode)
                    variant_id                => $product_data->{variant_id},
                    putaway_prep_group_id     => $pp_group->id,
                })->first
        }, $config->{test_type}.' variant is returned via search' );
        if ($config->{voucher}) {
            is( $inventory_item->variant_id, undef, 'variant_id is correct' );
            is( $inventory_item->voucher_variant_id, $product_data->{variant_id}, 'voucher_variant_id is correct' );
        } else {
            is( $inventory_item->variant_id, $product_data->{variant_id}, 'variant_id is correct' );
            is( $inventory_item->voucher_variant_id, undef, 'voucher_variant_id is correct' );
        }

    } # config test type
}


sub group_status_changes : Tests {
    my ($self) = @_;

    foreach my $config (
        {
            # normal
            test_type             => 'stock process',
            group_id_field_name   => 'pgid',
            pp_helper             => $self->{pp_helper},
            stock_filter_method   => 'filter_normal_stock',
            customer_returns_only => 0
        },
        {
            # recode
            test_type             => 'stock recode',
            recode                => 1,
            group_id_field_name   => 'recode_id',
            pp_helper             => $self->{pp_recode_helper},
            stock_filter_method   => 'filter_recodes',
            customer_returns_only => 0
        },
        {
            # return
            test_type             => 'stock return',
            return                => 1,
            group_id_field_name   => 'pgid',
            pp_helper             => $self->{pp_helper},
            stock_filter_method   => 'filter_returns',
            customer_returns_only => 1
        },
    ) {
        note("set up ".$config->{test_type});

        ############################################################
        # Setup: Create stock, and start a Putaway Prep Container
        ############################################################
        my ($stock_process, $product_data)
            = $self->{setup}->create_product_and_stock_process(1, {
                group_type => $config->{pp_helper}->name,
                return     => $config->{return},
                voucher    => $config->{voucher},
            }); # $stock_process might actually be a stock_recode
        my $group_id = $product_data->{ $config->{group_id_field_name} };
        my $sku = $product_data->{sku};
        note("using Group ID $group_id");
        my $pp_group = $self->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $config->{pp_helper}->name,
        });
        my $pp_container = $self->{setup}->create_pp_container;

        my $display_group;

        # build the display group using a combination of the handler and templates
        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        $display_group = $self->rebuild_display_group($pp_group, $config->{customer_returns_only});
        is( $display_group->{display_status}, 'Not Started', 'group is not started yet' );

        ############################################################
        # Scan one SKU
        ############################################################
        note("scan one SKU into container");
        $self->{pp_container_rs}->add_sku({
            container_id => $pp_container->container_id,
            sku          => $sku,
            putaway_prep => $config->{pp_helper},
            group_id     => $group_id,
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        $display_group = $self->rebuild_display_group($pp_group, $config->{customer_returns_only});
        is( $display_group->{display_status},                   'In Progress', 'group is in progress' );
        is( scalar(@{$display_group->{containers}}),            1, 'one container was used' );
        is( $display_group->{containers}[0]{id},                $pp_container->container_id, 'container ID is as expected' );
        is( $display_group->{containers}[0]{display_status},    '(blank)', 'container is in progress' );
        is( $display_group->{containers}[0]{quantity_scanned},  1, 'quantity scanned is as expected' );

        if (not $config->{return}) {
            ############################################################
            # Scan some more SKUs
            ############################################################
            note("scan four more SKUs into container");
            $self->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku          => $sku,
                putaway_prep => $config->{pp_helper},
                group_id     => $group_id,
            }) for 1 .. 4;

            $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
            $display_group = $self->rebuild_display_group($pp_group, $config->{customer_returns_only});
            is( $display_group->{display_status}, 'In Progress', 'group is still In Progress' );
            is( $display_group->{quantity_scanned}, 5, 'group quantity scanned is as expected' );
            is( $display_group->{containers}[0]{display_status}, '(blank)', 'container is still in progress' );
            is( $display_group->{containers}[0]{quantity_scanned}, 5, 'container quantity scanned is as expected' );
        }

        ############################################################
        # Finish the container
        ############################################################
        note("finish first container");
        $self->{pp_container_rs}->finish({
            container_id => $pp_container->container_id,
        });

        my $expected_count = $config->{return} ? 1 : 5;
        my $expected_status = $config->{return} ? 'Awaiting Putaway' : 'Part Complete';
        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        $display_group = $self->rebuild_display_group($pp_group, $config->{customer_returns_only});
        is( $display_group->{display_status}, $expected_status, "group is $expected_status" );
        is( $display_group->{quantity_scanned}, $expected_count, 'group quantity scanned remains as expected' );
        is( $display_group->{containers}[0]{display_status}, 'Sent', 'first container is in transit' );
        is( $display_group->{containers}[0]{quantity_scanned}, $expected_count, 'container quantity scanned remains as expected' );

        if (not $config->{return}) {
            ############################################################
            # Start a second container and scan one more SKU
            ############################################################
            note("set up second container");
            my $pp_container2 = $self->{setup}->create_pp_container;

            note("scan one SKU into second container");
            $self->{pp_container_rs}->add_sku({
                container_id => $pp_container2->container_id,
                sku          => $sku,
                putaway_prep => $config->{pp_helper},
                group_id     => $group_id,
            });

            $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
            $display_group = $self->rebuild_display_group($pp_group, $config->{customer_returns_only});
            is( scalar(@{$display_group->{containers}}), 2, 'two containers used' );
            is( $display_group->{display_status}, 'Part Complete', 'group remains Part Complete' );
            is( $display_group->{quantity_scanned}, 6, 'group quantity scanned sums both containers' );
            is( $display_group->{containers}[0]{id}, $pp_container->container_id, 'container 1 ID is correct');
            is( $display_group->{containers}[0]{quantity_scanned}, 5, 'first container quantity remains as 5' );
            is( $display_group->{containers}[1]{id}, $pp_container2->container_id, 'container 2 ID is correct');
            is( $display_group->{containers}[1]{display_status}, '(blank)', 'second container is in progress' );
            is( $display_group->{containers}[1]{quantity_scanned}, 1, 'second container quantity is 1' );

            ############################################################
            # Scan the remaining SKUs into second container
            ############################################################

            note("scan all remaining SKUs into second container");
            my $remaining_count = $stock_process->quantity - 6;
            $self->{pp_container_rs}->add_sku({
                container_id => $pp_container2->container_id,
                sku          => $sku,
                putaway_prep => $config->{pp_helper},
                group_id     => $group_id,
            }) for 1 .. $remaining_count;

            $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
            $display_group = $self->rebuild_display_group($pp_group, $config->{customer_returns_only});
            is( $display_group->{display_status}, 'Awaiting Putaway', 'group is Awaiting Putaway' );
            is( $display_group->{quantity_scanned}, $stock_process->quantity, 'group quantity scanned remains as the sum of both containers' );
            is( $display_group->{containers}[0]{quantity_scanned}, 5, 'first container quantity remains as 5' );
            is( $display_group->{containers}[1]{display_status}, '(blank)', 'second container remains in progress' );
            is( $display_group->{containers}[1]{quantity_scanned}, $remaining_count + 1, 'second container quantity is 5' );

            ############################################################
            # Finish the second container
            ############################################################
            note("finish container 2");
            $self->{pp_container_rs}->finish({
                container_id => $pp_container2->container_id,
            });

            $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
            $display_group = $self->rebuild_display_group($pp_group, $config->{customer_returns_only});
            is( $display_group->{containers}[1]{display_status}, 'Sent', 'second container is sent' );
            is( $display_group->{containers}[1]{quantity_scanned}, $remaining_count + 1, 'container quantity scanned remains as expected' );
        }

        is( $display_group->{display_status}, 'Awaiting Putaway', 'group is still Awaiting Putaway' );
        is( $display_group->{quantity_scanned}, $stock_process->quantity, 'group quantity scanned remains as the sum of both containers' );

        ############################################################
        # Scan one too many SKUs into another container
        ############################################################

        my $pp_container_overscan = $self->{setup}->create_pp_container;

        note("scan one too many SKUs into first container");
        $self->{pp_container_rs}->add_sku({
            container_id => $pp_container_overscan->container_id,
            sku => $sku,
            putaway_prep => $config->{pp_helper},
            group_id => $group_id,
        });

        note("finish overscan container");
        $self->{pp_container_rs}->finish({
            container_id => $pp_container_overscan->container_id,
        });

        $pp_group = $self->schema->resultset('Public::PutawayPrepGroup')->find($pp_group->id);
        $display_group = $self->rebuild_display_group($pp_group, $config->{customer_returns_only});
        is( $display_group->{display_status}, 'Problem', 'group has a Problem' );
        is( $display_group->{quantity_scanned}, $stock_process->quantity + 1, 'group quantity scanned is one more than the sum of both containers' );

    } # config: test types
}


sub same_container_reused_for_one_group : Tests {
    my ($self) = @_;

    my $config = {
        test_type           => 'stock process',
        group_id_field_name => 'pgid',
        pp_helper           => $self->{pp_helper},
        stock_filter_method => 'filter_normal_stock',
    };

    note("set up ".$config->{test_type});

    # Setup: Create stock, and start a Putaway Prep Container
    my ($stock_process, $product_data)
        = $self->{setup}->create_product_and_stock_process(1, {
            group_type => $config->{pp_helper}->name,
            return     => $config->{return},
            voucher    => $config->{voucher},
        }); # $stock_process might actually be a stock_recode
    my $group_id = $product_data->{ $config->{group_id_field_name} };
    my $sku = $product_data->{sku};
    note("using Group ID $group_id");
    my $pp_group = $self->{setup}->create_pp_group({
        group_id   => $group_id,
        group_type => $config->{pp_helper}->name,
    });
    my $pp_container = $self->{setup}->create_pp_container;

    my $display_group;

    # Scan one SKU
    note("scan one SKU into container");
    $self->{pp_container_rs}->add_sku({
        container_id => $pp_container->container_id,
        sku          => $sku,
        putaway_prep => $config->{pp_helper},
        group_id     => $group_id,
    }) for 1 .. 5;

    # Finish the container
    note("finish first container");
    $self->{pp_container_rs}->finish({
        container_id => $pp_container->container_id,
    });

    # Receive an AdviceResponse for the first container
    note("Pretend that we got advice response back from PRL");
    $self->fake_advice_response(
        response     => $PRL_TYPE__BOOLEAN__TRUE,
        container_id => $pp_container->container_id,
    );

    # pause for a second so that the last_scan_time is different
    sleep 1;

    # Restart same container
    note("Restart first container and scan another SKU");
    $self->{pp_container_rs}->start({
        container_id => $pp_container->container_id,
        user_id      => $APPLICATION_OPERATOR_ID,
    });
    # scan another SKU
    $self->{pp_container_rs}->add_sku({
        container_id => $pp_container->container_id,
        sku => $sku,
        putaway_prep => $config->{pp_helper},
        group_id => $group_id,
    });

    $display_group = $self->rebuild_display_group($pp_group, 0);
    is( scalar(@{$display_group->{containers}}), 2, 'two containers used' );
    is( $display_group->{containers}[0]{id}, $pp_container->container_id, 'container 1 ID is correct');
    is( $display_group->{containers}[0]{quantity_scanned}, 5, 'first container quantity is 5' );
    is( $display_group->{containers}[0]{display_status}, 'Putaway', 'first container is putaway' );
    is( $display_group->{containers}[1]{id}, $pp_container->container_id, 'container 2 ID is the same');
    is( $display_group->{containers}[1]{display_status}, '(blank)', 'second container is in progress' );
    is( $display_group->{containers}[1]{quantity_scanned}, 1, 'second container quantity is 1' );
}


# Utility methods

sub rebuild_display_group {
    my ($self, $pp_group, $customer_returns_only) = @_;

    # hit the database
    my $groups = $self->schema->resultset('Public::PutawayPrepInventory')
        ->prepare_data_for_putaway_admin($customer_returns_only);
    my $display_group = $groups->{ $pp_group->id };

    # $display_group = {
    #    channel_id          2,
    #    delivery            1939,
    #    delivery_date       DateTime,
    #    designer            "République ✪ Ceccarelli",
    #    group_id            2267,
    #    last_action         var{2267}{container_data}{M00735700001903}{last_scan_time},
    #    pgid                "p1825",
    #    pid                 3654,
    #    prl                 "Full PRL",
    #    quantity_expected   10,
    #    quantity_scanned    1,
    #    sku                 "3654-590",
    #    status_id           1,
    #    storage_type        "Flat",
    #    type                "Main",
    #    upload_date         DateTime,
    #    container_data      {
    #        M00735700001903   {
    #            destination        undef,
    #            failure_reason     undef,
    #            id                 "M00735700001903",
    #            last_scan_time     DateTime,
    #            operator           "Application",
    #            quantity_scanned   1,
    #            status_id          1
    #        }
    #    },
    #    containers          [
    #        [0] var{2267}{container_data}{M00735700001903}
    #    ],
    # };

    # group status
    $display_group->{display_status} = $self->_get_group_status($pp_group);

    # container statuses
    foreach my $display_container (@{ $display_group->{containers} }) {
        $display_container->{display_status}
            = $self->_get_container_status($display_container);
    }

    # sort containers by ID
    @{ $display_group->{containers} } = sort {
        $a->{id} cmp $b->{id}
        || DateTime->compare($a->{last_scan_time}, $b->{last_scan_time})
    } @{ $display_group->{containers} };

    note(">>> CONTAINERS");
    my $i = 0;
    foreach my $container (@{ $display_group->{containers} }) {
        note("\t> Container ".++$i);
        note("\tBarcode: ".$container->{id}->barcode);
        note("\tQuantity scanned: ".$container->{quantity_scanned});
        note("\tDisplay status: ".$container->{display_status});
        note("\tStatus ID: ".$container->{status_id});
        note("\tDestination: ".($container->{destination} ? $container->{destination}->location : 'undef'));
        note("\tFailure reason: ".($container->{failure_reason} ? $container->{failure_reason} : 'undef'));
    }

    return $display_group;
}

sub _get_group_status {
    my ($self, $pp_group) = @_;

    my @containers = $pp_group->putaway_prep_containers->all;

    my $template_vars = {
        containers             => \@containers,
        inventory_quantity     => $pp_group->inventory_quantity || undef,
        expected_quantity      => $pp_group->expected_quantity || undef,
        group_id               => $pp_group->canonical_group_id, # Used for error message
        group_display_status   => 'Unset',
        putaway_prep_group_row => $pp_group,
    };

    my $output = $self->process('putaway/group_status.tt', $template_vars);

    my ($status) = $output =~ m/group_display_status is "(.+)"/;
    return $status;
}

sub _get_container_status {
    my ($self, $display_container) = @_;

    my $template_vars = {
        status_id                => $display_container->{status_id},
        failure_reason           => $display_container->{failure_reason} || undef,
        container_display_status => 'Unset',
    };

    my $output = $self->process('putaway/container_status.tt', $template_vars);

    my ($status) = $output =~ m/container_display_status is "(.+)"/;
    if ($status eq '<!-- nothing displayed -->') { $status = '(blank)'; }

    return $status;
}

1;
