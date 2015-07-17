package Test::XTracker::Schema::ResultSet::Public::PutawayPrepContainer;

use NAP::policy "tt", 'test';

use parent 'NAP::Test::Class';
use Test::MockModule;
use Carp 'confess';

use Test::XTracker::RunCondition prl_phase => 'prl';

use Test::XTracker::Model; # create_product, create_variant
use Test::XTracker::Data;
use Test::XT::Data::Container;
use Test::XT::Data::PutawayPrep;

use XTracker::Config::Local qw( config_var );
use XTracker::Constants::FromDB qw(
    :container_status
    :putaway_prep_container_status
    :putaway_prep_group_status
    :stock_process_status
    :stock_process_type
    :storage_type
);
use XTracker::Constants qw/:prl_type/;
use NAP::DC::Exception::Overweight;
use NAP::DC::PRL::Tokens;
use XTracker::Database::PutawayPrep::RecodeBased;
use XT::Domain::PRLs;

sub startup :Test(startup => 8) {
    my ($test) = @_;
    $test->SUPER::startup();

    use_ok('XTracker::Database',':common');
    use_ok('XTracker::Handler');
    use_ok('XTracker::Database::PutawayPrep');

    $test->{pp_container_rs} = $test->schema->resultset('Public::PutawayPrepContainer');
    isa_ok($test->{pp_container_rs}, 'XTracker::Schema::ResultSet::Public::PutawayPrepContainer',"object is a PutawayPrep ResultSet");

    $test->{pp_helper} = XTracker::Database::PutawayPrep->new({ schema => $test->schema });
    isa_ok($test->{pp_helper}, 'XTracker::Database::PutawayPrep', 'XTracker::Database::PutawayPrep used okay');

    $test->{pp_recode_helper} = XTracker::Database::PutawayPrep::RecodeBased->new({ schema => $test->schema });
    isa_ok($test->{pp_recode_helper}, 'XTracker::Database::PutawayPrep::RecodeBased', 'XTracker::Database::PutawayPrep::RecodeBased used okay');

    $test->{setup} = Test::XT::Data::PutawayPrep->new;
}

sub teardown :Test(teardown) {
    my ($test) = @_;

    # make sure that test leave message dump directory in pristine state
    Test::XTracker::MessageQueue->new->clear_destination()
}

# TESTS

sub process_group_invalid : Tests {
    my ($test) = @_;

    # pgid that isn't a number
    throws_ok( sub {
        $test->{pp_helper}->is_group_id_suitable({
            group_id => 'foo oops',
        })
    }, qr/PGID\/Recode group ID is invalid. Please scan a valid PGID\/Recode group ID/,
    'Process group must be a number');
}


sub process_group_doesnt_exist : Tests {
    my ($test) = @_;

    # pgid that doesn't exist
    my $invalid_pgid = $test->schema->resultset('Public::StockProcess')->get_column('group_id')->max()+1;
    throws_ok( sub {
        $test->{pp_helper}->is_group_id_suitable({
            group_id => $invalid_pgid,
        })
    }, qr/Unknown PGID\/Recode group ID. Please scan a valid PGID\/Recode group ID/,
    'invalid pgid detected' );
}

sub wrong_stock_type : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};

    # products in process group are not correct type
    $stock_process->update({ type_id => $STOCK_PROCESS_TYPE__FAULTY });
    throws_ok( sub {
        $test->{pp_helper}->is_group_id_suitable({
            group_id => $pgid,
        })
    }, qr/PGID '\d+' cannot be put away as it has Putaway Type 'Goods In' and Stock Process Type 'Faulty'/,
    'invalid stock type detected' );
}

sub process_group_not_ready : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};

    # process group is not at correct stage of processing
    $stock_process->update({ status_id => $STOCK_PROCESS_STATUS__NEW });
    throws_ok( sub {
        $test->{pp_helper}->is_group_id_suitable({
            group_id => $pgid,
        })
    }, qr/PGID '\d+' cannot be put away as it has not completed 'Bag and Tag'/,
    'invalid stock process status detected' );
}

sub wrong_product_storage_type : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};

    # create absolutely new storage type that we will delete at the end of this test
    $test->_cleanup_test_storage_type(); # in case it was left behind previously
    my $new_storage_type = $test->schema
        ->resultset('Product::StorageType')
        ->create({name => 'test_foobar'});
    $new_storage_type->update;

    # change storage type to one that's not accepted,
    # retrieve product once again so it is aware of new storage type
    my $product = $test->schema
        ->resultset('Public::Product')
        ->search({id => $product_data->{product}->id})
        ->first;
    $product->update({ storage_type_id => $new_storage_type->id });

    throws_ok( sub {
        $test->{pp_helper}->is_group_id_suitable({
            group_id => $pgid,
        })
    }, qr/There is no PRL suitable for PGID 'p\d+'/,
    'invalid storage type detected' );

    $test->_cleanup_test_storage_type();
}

sub _cleanup_test_storage_type {
    my ($test) = @_;

    # clear down any data left from halfway-completed tests previously
    my $test_storage_type = $test->schema->resultset('Product::StorageType')
        ->search({name => 'test_foobar'});
    if ($test_storage_type->count) {
        $test->schema->resultset('Public::Product')->search({
            storage_type_id => $test_storage_type->first->id
        })->update({
            storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        });
        $test_storage_type->delete;
    }

}

sub wrong_putaway_type : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};

    $stock_process->update({ type_id => $STOCK_PROCESS_TYPE__FAULTY });

    throws_ok( sub {
        $test->{pp_helper}->is_group_id_suitable({
            group_id => $pgid,
        })
    }, qr/PGID '\d+' cannot be put away as it has Putaway Type 'Goods In' and Stock Process Type 'Faulty'/,
    'wrong putaway type detected' );
}

sub process_group_empty : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};

    $stock_process->update({ quantity => 0 });

    throws_ok( sub {
        $test->{pp_helper}->is_group_id_suitable({
            group_id => $pgid,
        })
    }, qr/PGID '\d+' does not contain any products/,
    'empty process group detected' );
}

sub process_group_would_break_mix_rules : Tests {
    my ($test) = @_;

    foreach my $config (
        {
            test_type           => 'stock process',
            recode              => 0,
            group_id_field_name => 'pgid',
            pp_helper           => $test->{pp_helper},
        },
        {
            test_type           => 'stock recode',
            recode              => 1,
            group_id_field_name => 'recode_id',
            pp_helper           => $test->{pp_recode_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        # setup
        my ($stock_process, $product_data)
            = $test->{setup}->create_product_and_stock_process( 1, {  group_type => $config->{pp_helper}->name });
        my $group_id = $product_data->{ $config->{group_id_field_name} };
        my $sku      = $product_data->{sku};
        my $pp_group = $test->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $config->{pp_helper}->name,
        });
        my $pp_container = $test->{setup}->create_pp_container;

        # add an item - should be okay
        lives_ok( sub {
            $test->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku          => $sku,
                putaway_prep => $config->{pp_helper},
                group_id     => $group_id,
            });
        }, "can add one item that's not overweight");

        # set up MixRules so that it will throw an exception (item too heavy)
        my $mockrules = Test::MockModule->new('NAP::DC::MixRules');
        $mockrules->mock('add', sub {
            NAP::DC::Exception::Overweight->new({
                current  => 10,
                addition => 2,
                limit    => 11,
                unit     => 'lb'
            })->throw;
        } );

        # scan Group ID (could be a different Group ID but is the same for this test),
        # should throw "early warning" mix rules error
        lives_ok(
            sub {
                $config->{pp_helper}->is_group_id_suitable({
                    group_id     => $group_id,
                    container_id => $pp_container->container_id,
                })
            },
            'No early warning of breaking mix rules (in case of overweight)'
        );
    } # test configs
}

sub process_group_valid : Tests {
    my ($test) = @_;

    foreach my $config (
        {
            test_type => 'stock process',
            recode => 0,
            group_id_field_name => 'pgid',
            pp_helper => $test->{pp_helper}
        },
        {
            test_type => 'stock recode',
            recode => 1,
            group_id_field_name => 'recode_id',
            pp_helper => $test->{pp_recode_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        # setup
        my ($stock_process, $product_data)
            = $test->{setup}->create_product_and_stock_process(1, { group_type => $config->{pp_helper}->name });

        is(
            $config->{pp_helper}->is_group_id_suitable({
                group_id => $product_data->{ $config->{group_id_field_name} }
            }),
            1,
            'valid Group ID detected'
        );
    }
}

sub start_container_already_in_progress : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    my $user_id = $test->{setup}->get_user_id;

    # start a container
    my $pp_container = $test->{setup}->create_pp_container;

    # ... time passes... operator goes for lunch
    # container becomes empty somehow
    # another operator picks up the same empty container

    # scan a container that's already in progress
    throws_ok( sub {
        $test->{pp_container_rs}->start({
            container_id => $pp_container->container_id,
            user_id => $user_id,
        }) },
        qr/Container .+ is already in progress/,
        'container cannot be started twice'
    );
}

sub add_too_heavy_item_to_container : Tests {
    my ($test) = @_;

    foreach my $config (
        {
            test_type           => 'stock process',
            recode              => 0,
            group_id_field_name => 'pgid',
            pp_helper           => $test->{pp_helper},
        },
        {
            test_type           => 'stock recode',
            recode              => 1,
            group_id_field_name => 'recode_id',
            pp_helper           => $test->{pp_recode_helper},
        },
    ) {
        note("set up ".$config->{test_type});

        # setup
        my ($stock_process, $product_data)
            = $test->{setup}->create_product_and_stock_process(1, { group_type => $config->{pp_helper}->name });
        my $group_id = $product_data->{ $config->{group_id_field_name} };
        my $sku      = $product_data->{sku};

        # set up MixRules so that it will throw an exception (item too heavy)
        my $mockrules = Test::MockModule->new('NAP::DC::MixRules');
        $mockrules->mock('add', sub {
            NAP::DC::Exception::Overweight->new({
                current  => 10,
                addition => 2,
                limit    => 11,
                unit     => 'lb'
            })->throw;
        } );

        # start a container
        my $pp_group = $test->{setup}->create_pp_group({
            group_id   => $group_id,
            group_type => $config->{pp_helper}->name,
        });
        my $pp_container = $test->{setup}->create_pp_container;

        throws_ok(
            sub { $test->{pp_container_rs}->add_sku({
                sku          => $sku,
                container_id => $pp_container->container_id,
                group_id     => $group_id,
                putaway_prep => $config->{pp_helper},
            }) },
            qr/\QContainer weight limit is 11.00 lb.  Current contents weight is 10.00 lb, so can't add item weighing 2.00 lb\E/,
            'too heavy item causes MixRules to throw an exception'
        );
    } # test configs
}

sub add_normal_item_to_container : Tests {
    my ($test) = @_;
    my $schema = $test->schema;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    my $sku = $product_data->{sku};
    my $variant_id = $product_data->{variant_id};

    # start a container
    my $pp_container = $test->{setup}->create_pp_container;
    my $pp_group     = $test->{setup}->create_pp_group({ group_id => $pgid });

    lives_ok {
        ok(
            $test->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku => $sku,
                group_id => $pgid,
                putaway_prep => $test->{pp_helper},
            }),
            'item added to container'
        )
    } 'normal item added to container';

    is(
        $test->get_sku_from_variant_id(
            $test->{pp_container_rs}->find_in_progress({
                container_id => $pp_container->container_id,
            })->search_related('putaway_prep_inventories')->search({
                variant_id => $variant_id,
            })->first->variant_id,
        ),
        $sku,
        'item is added in database'
    );
}

sub add_recode_item_to_container : Tests {
    my ($test) = @_;
    my $schema = $test->schema;

    # setup
    my ($stock_process, $product_data)
        = $test->{setup}->create_product_and_stock_process(1, {
            group_type => XTracker::Database::PutawayPrep::RecodeBased->name
        });
    my $rgid = $product_data->{recode_id};
    note "DSP: got rgid $rgid";
    my $sku = $product_data->{sku};
    my $variant_id = $product_data->{variant_id};

    # start a container
    my $pp_container = $test->{setup}->create_pp_container;
        my $pp_group = $test->{setup}->create_pp_group({
            group_id   => $rgid,
            group_type => XTracker::Database::PutawayPrep::RecodeBased->name,
        });

    lives_ok {
        ok (
            $test->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku => $sku,
                group_id => $rgid,
                putaway_prep => $test->{pp_recode_helper},
            }),
            'item added to container'
        )
    } 'normal item added to container';

    is(
        $test->get_sku_from_variant_id(
            $test->{pp_container_rs}->find_in_progress({
                container_id => $pp_container->container_id,
            })->search_related('putaway_prep_inventories')->search({
                variant_id => $variant_id,
            })->first->variant_id,
        ),
        $sku,
        'item is added in database'
    );
}

sub remove_item_from_container : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    my $sku = $product_data->{sku};
    my $variant_id = $product_data->{variant_id};

    # start a container
    my $pp_group = $test->{setup}->create_pp_group({ group_id => $pgid });
    my $pp_container = $test->{setup}->create_pp_container;

    # add an item to container
    $test->{pp_container_rs}->add_sku({
        container_id => $pp_container->container_id,
        sku => $sku,
        group_id     => $pgid,
        putaway_prep => $test->{pp_helper},
    });

    # and again
    $test->{pp_container_rs}->add_sku({
        container_id => $pp_container->container_id,
        sku => $sku,
        putaway_prep => $test->{pp_helper},
        group_id => $pgid,
    });

    # should be two items now
    is(
        $test->{pp_container_rs}->find_in_progress({
            container_id => $pp_container->container_id,
        })->search_related('putaway_prep_inventories')->search({
            variant_id => $variant_id,
        })->first->quantity,
        2,
        'two test items added'
    );

    # remove one item
    lives_ok {
        is (
            $pp_container->remove_sku($sku),
            1,
            'item removed from container'
        )
    } 'remove_sku works';

    # should be one item left
    is(
        $test->{pp_container_rs}->find_in_progress({
            container_id => $pp_container->container_id,
        })->search_related('putaway_prep_inventories')->search({
            variant_id => $variant_id,
        })->first->quantity,
        1,
        'item removed in database'
    );

    # remove non-existent item
    my (undef, $product_data_two) = $test->{setup}->create_product_and_stock_process;
    throws_ok {
        $pp_container->remove_sku($product_data_two->{sku});
    } qr/Cannot remove SKU/,
    'remove_sku works';

    # remove the other item
    lives_ok {
        is (
            $pp_container->remove_sku($sku),
            1,
            'item removed from container'
        )
    } 'remove_sku works';

    # no more container record should be left
    is(
        $test->{pp_container_rs}->find_in_progress({
            container_id => $pp_container->container_id,
        }),
        undef,
        'No more container record is left in database'
    );

    # should be none left
    is(
        $test->schema->resultset('Public::PutawayPrepInventory')->search({
            putaway_prep_container_id => $pp_container->id
        })->first,
        undef,
        'items removed in database'
    );
}

sub add_non_existent_item_to_container : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};

    # start a container
    my $pp_group = $test->{setup}->create_pp_group({ group_id => $pgid });
    my $pp_container = $test->{setup}->create_pp_container;

    throws_ok( sub { $test->{pp_container_rs}->add_sku({
        container_id => $pp_container->container_id,
        group_id     => $pgid,
        sku          => 'this_doesnt_exist',
        putaway_prep => $test->{pp_helper},
    }) }, qr/Cannot recognise SKU/, 'non-existent item detected');

}

sub get_skus_for_pgid : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};

    my $skus = $test->{pp_helper}->get_skus_for_group_id( $pgid );
    ok( ref($skus) eq 'ARRAY', 'Arrayref of SKUs returned');
    ok( scalar(@$skus) > 0, 'SKUs were found for pgid');
}

sub container_complete_stock_process : Tests {
    my ($test) = @_;
    $test->_container_complete({
        test_type => 'stock process',
        recode => 0,
        group_id_field_name => 'pgid',
        pp_helper => $test->{pp_helper},
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
    });
}

sub container_complete_stock_recode : Tests {
    my ($test) = @_;
    $test->_container_complete({
        test_type => 'stock recode',
        recode => 1,
        group_id_field_name => 'recode_id',
        pp_helper => $test->{pp_recode_helper},
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
    });
}

sub container_complete_dematic_flat : Tests {
    my ($test) = @_;
    $test->_container_complete({
        test_type => 'stock process',
        recode => 0,
        group_id_field_name => 'pgid',
        pp_helper => $test->{pp_helper},
        storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
    });
}

sub _container_complete {
    my ($test, $config) = @_;

    note("set up ".$config->{test_type});

    # setup
    my ($stock_process, $product_data)
        = $test->{setup}->create_product_and_stock_process(1, {
            group_type => (
                $config->{recode}
                    ? XTracker::Database::PutawayPrep::RecodeBased->name
                    : XTracker::Database::PutawayPrep->name
            ),
        });
    my $group_id = $product_data->{ $config->{group_id_field_name} };
    my $sku = $product_data->{sku};

    # start a container
    my $pp_group = $test->{setup}->create_pp_group({
        group_id => $group_id,
        group_type => (
            $config->{recode}
                ? XTracker::Database::PutawayPrep::RecodeBased->name
                : XTracker::Database::PutawayPrep->name
        ),
    });
    my $pp_container = $test->{setup}->create_pp_container;

    # add one item to container so it is not empty
    lives_ok {
        ok (
            $test->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku => $sku,
                group_id     => $group_id,
                putaway_prep => $config->{pp_helper},
            }),
            'item added to container'
        )
    } 'normal item added to container';


    # all messages being sent with code below are dumped into directory
    my $amq = Test::XTracker::MessageQueue->new;

    # clean up queue dump directory (just in case)
    $amq->clear_destination();

    # mark container complete
    is(
        $test->{pp_container_rs}->finish({
            container_id => $pp_container->container_id,
        }),
        1,
        'finished container'
    );

    my $container_rs = $test->{pp_container_rs}->search({
        container_id => $pp_container->container_id,
        putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
    });

    is(
        $container_rs->count, 1,
        'container is marked complete in database'
    );

    ok(
        $container_rs->first->destination,
        'Container destination was populated after advice is sent'
    );

    my $number_of_prls = XT::Domain::PRLs::get_number_of_prls;

    # check the number of sent messages: expect one advice message and one sku
    # update for each PRL
    $amq->assert_messages({
        filter_header => superhashof({
            type => 'sku_update',
        }),
        assert_count => $number_of_prls,
    }, 'many SKU Update messages were sent.' );

    $amq->assert_messages({
        filter_header => superhashof({
            type => 'advice',
        }),
        assert_count => 1,
    }, 'one Advice message was sent.' );

    $amq->assert_messages({
        assert_count => 1 + $number_of_prls,
    }, 'no other messages were sent.' );

    # clean up
    $amq->clear_destination();

}

sub is_group_id_valid :Tests {
    my ($test) = @_;

    ok $test->{pp_helper}->is_group_id_valid('1234');
    ok $test->{pp_helper}->is_group_id_valid('p1234');
    ok $test->{pp_helper}->is_group_id_valid('P1234');
    ok not $test->{pp_helper}->is_group_id_valid('p 1234');
    ok not $test->{pp_helper}->is_group_id_valid('a123123');

    ok $test->{pp_recode_helper}->is_group_id_valid('123');
    ok $test->{pp_recode_helper}->is_group_id_valid('r123');
    ok $test->{pp_recode_helper}->is_group_id_valid('R123');
}

# Check case when there is an attempt to scan SKU into container
# with items from different client
#
sub add_sku_mixrule_client_failure : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    my $sku = $product_data->{sku};

    # start a container
    my $pp_group = $test->{setup}->create_pp_group({ group_id => $pgid });
    my $pp_container = $test->{setup}->create_pp_container;

    # add an item - should be okay
    lives_ok( sub {
        $test->{pp_container_rs}->add_sku({
            container_id => $pp_container->container_id,
            sku          => $sku,
            group_id     => $pgid,
            putaway_prep => $test->{pp_helper},
        });
    }, "can add one item that's not overweight");

    # set up MixRules so that it will throw an mix rules exception
    my $mockrules = Test::MockModule->new('NAP::DC::MixRules');
    $mockrules->mock('add', sub {
        NAP::DC::Exception::MixRules->new({
            conflict_type  => 'client',
            conflicts_with => {client => $NAP::DC::PRL::Tokens::dictionary{CLIENT}->{JC}},
        })->throw;
    } );

    # get the expected error message
    my $client = 'Jimmy Choo';

    my $error_msg = sprintf( 'SKU %s cannot be added to container %s because it'
        . ' contains item belonging to %s. This SKU does not belong to %s. Please'
        . " start new container for this SKU",
        $sku, $pp_container->container_id, $client, $client
    );

    # check that MixRule error is handled correctly
    throws_ok(
        sub {
            $test->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku          => $sku,
                group_id     => $pgid,
                putaway_prep => $test->{pp_helper},
            });
        },
        qr/$error_msg/,
        'Error message for client violation is shown'
    );
}

# check attempt to scan SKU into container containing the same SKU but different PGID
#
sub add_sku_mixrule_pgid_failure : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    my $sku = $product_data->{sku};

    # start a container
    my $pp_group = $test->{setup}->create_pp_group({ group_id => $pgid });
    my $pp_container = $test->{setup}->create_pp_container;

    # add an item - should be okay
    lives_ok( sub {
        $test->{pp_container_rs}->add_sku({
            container_id => $pp_container->container_id,
            sku          => $sku,
            group_id     => $pgid,
            putaway_prep => $test->{pp_helper},
        });
    }, "can add one item that's not overweight");

    # set up MixRules so that it will throw an mix rules exception
    my $mockrules = Test::MockModule->new('NAP::DC::MixRules');
    $mockrules->mock('add', sub {
        NAP::DC::Exception::MixRules->new({
            conflict_type  => 'pgid',
            conflicts_with => {pgid => 123},
        })->throw;
    } );

    my $error_msg = sprintf('SKU %s cannot be added to container %s because'
        . ' the container %s contains the same SKU with PGID %s. Please'
        . ' start new container for this SKU',
        $sku, $pp_container->container_id, $pp_container->container_id, 123
    );

    # check that MixRule error is handled correctly
    throws_ok(
        sub {
            $test->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku => $sku,
                putaway_prep => $test->{pp_helper},
                group_id => $pgid,
            });
        },
        qr/$error_msg/,
        'Error message for SKU/PGID relations violation is shown'
    );
}

# attempt to scan SKU into container with same SKU but different stock status
#
sub add_sku_mixrule_stock_status_failure : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    my $sku = $product_data->{sku};

    # start a container
    my $pp_group = $test->{setup}->create_pp_group({ group_id => $pgid });
    my $pp_container = $test->{setup}->create_pp_container;

    # add an item - should be okay
    lives_ok( sub {
        $test->{pp_container_rs}->add_sku({
            group_id     => $pgid,
            container_id => $pp_container->container_id,
            sku          => $sku,
            putaway_prep => $test->{pp_helper},
        });
    }, "can add one item that's not overweight");

    # set up MixRules so that it will throw an mix rules exception
    my $mockrules = Test::MockModule->new('NAP::DC::MixRules');
    $mockrules->mock('add', sub {
        NAP::DC::Exception::MixRules->new({
            conflict_type  => 'status',
            conflicts_with => {status => 123},
        })->throw;
    } );

    my $error_msg = sprintf('SKU %s cannot be added to container %s because'
        . ' the container contains the same SKU with stock status %s. Please'
        . ' start new container for this SKU',
        $sku, $pp_container->container_id, 123
    );

    # check that MixRule error is handled correctly
    throws_ok(
        sub {
            $test->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku => $sku,
                putaway_prep => $test->{pp_helper},
                group_id => $pgid,
            });
        },
        qr/$error_msg/,
        "can add one item that's not overweight"
    );
}

# check attempt to scan SKU into container with items of different family
#
sub add_sku_mixrule_family_failure : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    my $sku = $product_data->{sku};

    # start a container
    my $pp_group = $test->{setup}->create_pp_group({ group_id => $pgid });
    my $pp_container = $test->{setup}->create_pp_container;

    # add an item - should be okay
    lives_ok( sub {
        $test->{pp_container_rs}->add_sku({
            container_id => $pp_container->container_id,
            sku => $sku,
            putaway_prep => $test->{pp_helper},
            group_id => $pgid,
        });
    }, "can add one item that's not overweight");

    # set up MixRules so that it will throw an mix rules exception
    my $mockrules = Test::MockModule->new('NAP::DC::MixRules');
    $mockrules->mock('add', sub {
        NAP::DC::Exception::MixRules->new({
            conflict_type  => 'family',
            conflicts_with => {family => $PRL_TYPE__FAMILY__VOUCHER},
        })->throw;
    } );

    my $error_msg = sprintf( 'SKU %s cannot be added to container %s because'
        . ' the container contains %s and the SKU is %s. Please'
        . ' start new container for this SKU',
        $sku, $pp_container->container_id, $PRL_TYPE__FAMILY__VOUCHER, $PRL_TYPE__FAMILY__GARMENT
    );

    # check that MixRule error is handled correctly
    throws_ok(
        sub {
            $test->{pp_container_rs}->add_sku({
                container_id => $pp_container->container_id,
                sku => $sku,
                putaway_prep => $test->{pp_helper},
                group_id => $pgid,
            });
        },
        qr/$error_msg/,
        'Error message for SKU family violation is shown'
    );
}

sub restart_failed_container : Tests {
    my ($test) = @_;

    # setup
    my ($stock_process, $product_data) = $test->{setup}->create_product_and_stock_process;
    my $pgid = $product_data->{pgid};
    my $sku = $product_data->{sku};

    # start a container
    my $pp_group = $test->{setup}->create_pp_group({ group_id => $pgid });
    my $pp_container = $test->{setup}->create_pp_container;

    # add an item
    $test->{pp_container_rs}->add_sku({
        container_id => $pp_container->container_id,
        sku => $sku,
        putaway_prep => $test->{pp_helper},
        group_id => $pgid,
    });

    # finish container
    $test->{pp_container_rs}->finish({
        container_id => $pp_container->container_id,
    });

    # fail container
    $pp_container->update({
        putaway_prep_status_id => $PUTAWAY_PREP_CONTAINER_STATUS__FAILURE,
        failure_reason => 'Test failure',
    });

    # try to start failed container - should fail
    my $container_id = $pp_container->container_id;
    throws_ok( sub {
        $test->{pp_container_rs}->start({
            container_id => $pp_container->container_id,
            user_id => $test->{setup}->get_user_id,
        }) },
        qr/^Container '$container_id' is already in progress/,
        'cannot start a failed container'
    );
}

=head1 UTILITY FUNCTIONS

=cut

sub get_sku_from_variant_id {
    my ($test, $variant_id) = @_;
    confess "$variant_id looks like a SKU, not a variant ID" if $variant_id =~ m/\-/;
    return $test->schema->resultset('Public::Variant')->find($variant_id)->sku;
}

1;
