package Test::NAP::StockControl::ChannelTransfer;

use NAP::policy 'test';

=head1 NAME

Test::NAP::StockControl::ChannelTransfer - Test channel transfers

=head1 DESCRIPTION

Test channel transfers, with and without outstanding PIDs

#TAGS inventory iws prl phase0 channeltransfer loops checkruncondition whm

=cut

use Test::XTracker::Data;
use Test::Most;
use Test::XT::Flow;
use XTracker::Constants             qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB     qw(
                                          :authorisation_level
                                          :channel_transfer_status
                                          :flow_status
                                          :stock_process_status
                                          :stock_process_type
                                          :storage_type
                                  );
use Test::XT::Data::Container;
use XTracker::Config::Local qw(config_var);
use XT::JQ::DC::Receive::Product::ChannelTransfer;
use XTracker::Database::ChannelTransfer;
use XTracker::Database::Product;

# We skip DC3 as we only have one enabled channel
use Test::XTracker::RunCondition dc => [ qw/DC1 DC2/ ], export => [qw( $iws_rollout_phase $prl_rollout_phase )];

use parent 'NAP::Test::Class';

sub startup : Test(startup) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [qw/
            Test::XT::Data::Location
            Test::XT::Data::PurchaseOrder
            Test::XT::Data::Quantity
            Test::XT::Data::Samples
            Test::XT::Flow::Fulfilment
            Test::XT::Flow::PrintStation
            Test::XT::Flow::Samples
            Test::XT::Flow::StockControl
            Test::XT::Flow::StockControl::Quarantine
            Test::XT::Flow::WMS
        /],
    );
    $self->{schema} = $self->{framework}->schema;
    $self->{framework}->mech->force_datalite(1);
    $self->{automatic} = $iws_rollout_phase || $prl_rollout_phase;
    $self->{'prl_loc'} = 'Full PRL' if $prl_rollout_phase;

    Test::XTracker::Data->ensure_non_iws_locations()
        unless $self->{automatic};
}

## Test double selection submission on DC1
sub nap_out_double_submit_error : Tests {
    my ( $self ) = @_;

    return unless $self->{automatic};

    my $source_channel = Test::XTracker::Data->channel_for_nap;
    my $dest_channel = Test::XTracker::Data->channel_for_out;

    my ($product) = Test::XTracker::Data->create_test_products({
        how_many => 1,
        channel_id => $source_channel->id,
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
    });

    $self->{'framework'}->flow_task__stock_control__channel_transfer_auto({
            product => $product,
            channel_from => $source_channel,
            channel_to   => $dest_channel,
            schema => $self->{'schema'},
            expect_error => "PID ".$product->id." has already been selected",
            double_submit => 1,
            prl_loc => $self->{'prl_loc'},
        });
}


sub mrp_out_nap : Tests {
    my ( $self ) = @_;

    return unless $self->{schema}->resultset('Public::Channel')->channels_enabled( qw( MRP OUTNET NAP ) );

    my $source_channel = Test::XTracker::Data->channel_for_mrp;
    my ($product) = Test::XTracker::Data->create_test_products({
        how_many => 1,
        channel_id => $source_channel->id,
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
    });
    $self->call_channel_transfer({
        product => $product,
        channels => [
            $source_channel,
            Test::XTracker::Data->channel_for_out,
            Test::XTracker::Data->channel_for_nap,
        ],
    });
}

sub validate_cross_client_transfers : Tests {
    my ( $self ) = @_;

    # get clients
    my @clients = $self->{schema}->resultset('Public::Client')->all;

    # matrix test transfer to and from each client
    for my $source_client (@clients) {
        # find a source channel
        my $source_channel = $source_client->businesses->search_related('channels', undef, { rows => 1 })->slice(0,0)->single;
        for my $dest_client (@clients) {
            # find a destination channel
            my $dest_channel = $dest_client->businesses->search_related('channels', { 'channels.id' => { '!=' => $source_channel->id } }, { rows => 1})->slice(0,0)->single;
            if ($dest_channel) {
                note 'From client '.$source_client->prl_name.' to client '.$dest_client->prl_name;
                note 'From channel '.$source_channel->business->config_section.' to channel '.$dest_channel->business->config_section;

                my ($product) = Test::XTracker::Data->create_test_products({
                    channel_id => $source_channel->id,
                    storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
                });

                # make fake job
                my $job = XT::JQ::DC::Receive::Product::ChannelTransfer->new({
                    payload => {
                        source_channel => $source_channel->id,
                        dest_channel => $dest_channel->id,
                        currency => '',
                        operator_id => $APPLICATION_OPERATOR_ID,
                        products => [
                            {
                                product => $product->id,
                                price => 0,
                            },
                        ],
                    },
                });

                if ($source_client->id == $dest_client->id) {
                    # transfers between channels for the same client should be allowed
                    my @errors;
                    lives_ok sub { @errors = $job->check_job_payload }, 'channel transfer payload should pass validation';
                } else {
                    # transfers between channels for different clients should be prohibited
                    my @errors;
                    dies_ok sub { @errors = $job->check_job_payload }, 'channel transfer payload should not pass validation';
                    like $@, qr/Source and destination channels must belong to the same client/, 'validation should return cross-client transfer error';
                }
            } else {
                note 'Not enough channels available to transfer from client '.$source_client->prl_name.' to client '.$dest_client->prl_name;
            }
        }
    }
}

sub nap_out_mrp : Tests {
    my ( $self ) = @_;

    return unless $self->{schema}->resultset('Public::Channel')->channels_enabled( qw( NAP OUTNET MRP ) );

    my $source_channel = Test::XTracker::Data->channel_for_nap;
    my ($product) = Test::XTracker::Data->create_test_products({
        how_many => 1,
        channel_id => $source_channel->id,
        storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
    });
    $self->call_channel_transfer({
        product => $product,
        channels => [
            $source_channel,
            Test::XTracker::Data->channel_for_out,
            Test::XTracker::Data->channel_for_mrp,
        ],
    });
}

sub test_with_dead_stock : Tests {
    my $self = shift;

    my $source_channel = Test::XTracker::Data->channel_for_mrp;
    my $dest_channel   = Test::XTracker::Data->channel_for_out;
    my ($product) = Test::XTracker::Data->create_test_products({
            how_many => 1,
            channel_id => $source_channel->id,
            storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
       });
    if ($self->{automatic}) {
        $self->{'framework'}->flow_task__stock_control__channel_transfer_auto({
                product => $product,
                channel_from => $source_channel,
                channel_to   => $dest_channel,
                schema => $self->{'schema'},
                status_id => $FLOW_STATUS__DEAD_STOCK__STOCK_STATUS,
                prl_loc => $self->{'prl_loc'},
            });
    }
}

sub test_with_not_in_main_stock : Tests {
    my ( $self ) = @_;


    unless ($self->{automatic}) {
        return;
    }

    my $source_channel = Test::XTracker::Data->channel_for_nap;
    my $dest_channel   = Test::XTracker::Data->channel_for_out;
    my $scenarios = [
        {
            status_id => $FLOW_STATUS__IN_TRANSIT_FROM_IWS__STOCK_STATUS,
            expected_error => " has units that are in transit and cannot be transferred to another channel."
        },
        {
            status_id => $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
            expected_error => " has units that are transfer pending and cannot be transferred to another channel."
        },
        {
            status_id => $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS,
            expected_error => " has units that are transfer pending and cannot be transferred to another channel."
        },
        {
            status_id => $FLOW_STATUS__QUARANTINE__STOCK_STATUS,
            expected_error => " has units that are in Quarantine and cannot be transferred to another channel."
        },
        {
            status_id => $FLOW_STATUS__SAMPLE__STOCK_STATUS,
            expected_error => " has units that are booked out in sample area and cannot be transferred to another channel."
        },
        {
            status_id => $FLOW_STATUS__CREATIVE__STOCK_STATUS,
            expected_error => " has units that are booked out in sample area and cannot be transferred to another channel."
        },
        {
            status_id => $FLOW_STATUS__RTV_WORKSTATION__STOCK_STATUS,
            expected_error => " has units that are in RTV processing and cannot be transferred to another channel."
        },

    ];
    foreach my $scenario (@{$scenarios}){
        my ($product) = Test::XTracker::Data->create_test_products({
            how_many => 1,
            channel_id => $source_channel->id,
            storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        });

        $self->{'framework'}->flow_task__stock_control__channel_transfer_auto({
            product => $product,
            channel_from => $source_channel,
            channel_to   => $dest_channel,
            schema => $self->{'schema'},
            status_id => $scenario->{status_id},
            expect_error => "PID ".$product->id.$scenario->{expected_error},
            prl_loc => $self->{'prl_loc'},
        });

    }
}

sub test_prevent_duplicate_transfer : Tests {
    my ( $self ) = @_;

    my $channel_nap = Test::XTracker::Data->channel_for_nap;
    my $channel_mrp = Test::XTracker::Data->channel_for_mrp;
    my $channel_out = Test::XTracker::Data->channel_for_out;

    my $transfer_test = sub {
        my ( $source_and_dest_channel1, $source_and_dest_channel2, $expected_error ) = @_;

        my $create_fake_job = sub {
            my ( $source_channel, $dest_channel, $products ) = @_;

            return XT::JQ::DC::Receive::Product::ChannelTransfer->new({
                payload => {
                    source_channel => $source_channel->id,
                    dest_channel => $dest_channel->id,
                    currency => '',
                    operator_id => $APPLICATION_OPERATOR_ID,
                    products => [
                        map {
                            {
                                product => $_->id,
                                price => 0,
                            }
                        } @$products
                    ],
                },
            });
        };

        # Create fake message for first transfer
        my ( $source_channel, $dest_channel ) = @$source_and_dest_channel1;
        my ( $product1, $product2, $product3 ) = Test::XTracker::Data->create_test_products({
            how_many => 3,
            channel_id => $source_channel->id,
            storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        });
        my $job1 = $create_fake_job->( $source_channel, $dest_channel, [$product1,$product2,$product3] );

        # Validation for first message should pass
        lives_ok sub { $job1->check_job_payload }, 'first transfer request should pass validation';

        # Create ChannelTransfer row for the first transfer
        lives_ok sub { $job1->do_the_task }, 'first transfer should be created';

        # Create fake message for second transfer
        ( $source_channel, $dest_channel ) = @$source_and_dest_channel2;
        my $job2 = $create_fake_job->( $source_channel, $dest_channel, [$product2] );

        # Validation for second message should fail
        dies_ok sub { $job2->check_job_payload }, 'second transfer request should fail validation';
        my $product2_id = $product2->id;
        like $@, qr{\b$expected_error for product $product2_id\b}, "validation should return '$expected_error' error";
    };

    subtest 'refuse_conflicting_channel_transfer' => sub {
        SKIP: {
            skip 'Test requires NAP, OUTNET and MRP to be enabled', 1 unless $self->{schema}->resultset('Public::Channel')->channels_enabled( qw( NAP OUTNET MRP ) );
            $transfer_test->(
                [ $channel_nap, $channel_out ],
                [ $channel_nap, $channel_mrp ],
                'conflicting channel transfer requested',
            );
        }
    };

    subtest 'refuse_concurrent_channel_transfer' => sub {
        SKIP: {
            skip 'Test requires NAP, OUTNET and MRP to be enabled', 1 unless $self->{schema}->resultset('Public::Channel')->channels_enabled( qw( NAP OUTNET MRP ) );
            $transfer_test->(
                [ $channel_nap, $channel_out ],
                [ $channel_out, $channel_mrp ],
                'channel transfer already requested',
            );
        }
    };

    subtest 'refuse_duplicate_channel_transfer' => sub {
        SKIP: {
            skip 'Test requires NAP and OUTNET to be enabled', 1 unless $self->{schema}->resultset('Public::Channel')->channels_enabled( qw( NAP OUTNET ) );
            $transfer_test->(
                [ $channel_nap, $channel_out ],
                [ $channel_nap, $channel_out ],
                'duplicate channel transfer requested',
            );
        }
    };
}

sub test_rollback : Tests {
    my ( $self ) = @_;

    my $rollback_test = sub {
        my $die_msg = shift;
        my $source_channel = Test::XTracker::Data->channel_for_nap;
        my $dest_channel = Test::XTracker::Data->channel_for_out;
        my ($product) = Test::XTracker::Data->create_test_products({
            how_many => 1,
            channel_id => $source_channel->id,
            storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        });
        my @transfers = $self->call_channel_transfer({
            product => $product,
            channels => [$source_channel, $dest_channel],
            stop_after_selection => 1,
        });
        is( @transfers, 1, 'there should only be one transfer' );

        throws_ok( sub {
            XTracker::Database::ChannelTransfer::complete_auto_channel_transfer(
                $self->{schema}, $transfers[0]->id, $APPLICATION_OPERATOR_ID );
        }, qr{$die_msg}, 'channel transfer should die at stock change' );
        # Being lazy and just checking just one of the changes was rolled back
        is( $transfers[0]->status_id, $CHANNEL_TRANSFER_STATUS__SELECTED,
            sprintf(
                q{All changes should have been rolled back for product %d},
                $transfers[0]->product_id
            )
        );
    };
    subtest 'rollback_near_end_of_transaction' => sub {
        plan skip_all => q{No tests for non-IWS rollbacks} unless $iws_rollout_phase;
        no warnings 'redefine';
        my $die_msg = 'dying to test rollback';
        use XTracker::WebContent::StockManagement::Broadcast;
        local *XTracker::WebContent::StockManagement::Broadcast::new = sub {
            die $die_msg;
        };
        $rollback_test->($die_msg);
    };
    subtest 'rollback_when mysql update dies' => sub {
        plan skip_all => q{No tests for non-IWS rollbacks} unless $iws_rollout_phase;
        no warnings 'redefine';
        my $die_msg = 'dying to test rollback';
        use DBD::Mock::db;
        local *DBD::Mock::db::commit = sub {
            die $die_msg;
        };
        $rollback_test->($die_msg);
    };
}

# Per DCEA-1550 and others, Channel Transfers should not be able to be performed
# when we have outstanding putaways for the stock.
sub test_with_outstanding_pgids : Tests {
    my ( $self ) = @_;

    unless ($iws_rollout_phase) {
        # TODO: set up some sensible tests here
        return;
    }

    my $source_channel = Test::XTracker::Data->channel_for_nap;

    # We're going to start a couple of scenarios with products that have been
    # marked faulty, so set up a coderef for that now.
    my $from_faulty = sub {
        my ($self, $product, $to_stock_type)= @_;
        my $variant = $product->variants->first;

        $self->{framework}->flow_wms__send_inventory_adjust(
            sku => $variant->sku,
            quantity_change => -1,
            reason => 'STOCK OUT TO XT',
            stock_status => 'main',
        );
        $self->{framework}->task__set_printer_station(qw/StockControl Quarantine/);
        $self->{framework}->flow_mech__stockcontrol__inventory_stockquarantine( $product->id );
        my ($quarantine_note, $faulty_item_quantity_obj) =
            $self->{framework}->flow_mech__stockcontrol__inventory_stockquarantine_submit(
                variant_id => $variant->id,
                location => 'Transit',
                quantity => 1,
                type => 'L'
            );
        my $stock_process_group_id = $self->{framework}
            ->flow_mech__stockcontrol__quarantine_processitem(
                $faulty_item_quantity_obj->id
            )->flow_mech__stockcontrol__quarantine_processitem_submit(
                ($to_stock_type) => 1
        );

        my @sp = $self->{schema}->resultset('Public::StockProcess')->search({
            group_id => $stock_process_group_id});
        return @sp;
    };

    my $outstanding_error_regex =
        qr/PID \d+ still has items that need to be putaway before we can commence the channel transfer/;

    # Each of these scenarios puts a product in a position from which we should
    # refuse to do a channel transfer
    foreach my $scenario (
        {
            'name'  => 'PO goods in pre_advices pre bag and tag',
            'error' => $outstanding_error_regex,
            'setup' => sub { # Called with the test product we'll create
                my ( $self, $product ) = @_;

                # Create a purchase order, process, group, and take it to as far
                # as approved in the DB, as if we're waiting for a
                # stock_received from IWS, and return the associated stock
                # processes
                return
                    # Create the stock processes from deliveries
                    map {
                        Test::XTracker::Data->create_stock_process_for_delivery( $_, {
                            status_id => $STOCK_PROCESS_STATUS__APPROVED,
                            type_id   => $STOCK_PROCESS_TYPE__MAIN,
                        })
                    }
                    # Create a delivery in the putaway state
                    Test::XTracker::Data->create_delivery_for_po(
                        # Create a purchase order for the product, and get its ID
                        Test::XTracker::Data->setup_purchase_order([ $product->id ])->id,
                        'putaway'
                    );
            }
        }, {
            'name'  => 'PO goods in pre_advices post bag and tag',
            'error' => $outstanding_error_regex,
            'setup' => sub { # Called with the test product we'll create
                my ( $self, $product ) = @_;

                # Create a purchase order, process, group, and take it to as far
                # as bag-and-tag in the DB, as if we're waiting for a
                # stock_received from IWS, and return the associated stock
                # processes
                return
                    # Create the stock processes from deliveries
                    map {
                        Test::XTracker::Data->create_stock_process_for_delivery( $_, {
                            status_id => $STOCK_PROCESS_STATUS__BAGGED_AND_TAGGED,
                            type_id => $STOCK_PROCESS_TYPE__MAIN,
                        })
                    }
                    # Create a delivery in the putaway state
                    Test::XTracker::Data->create_delivery_for_po(
                        # Create a purchase order for the product, and get its ID
                        Test::XTracker::Data->setup_purchase_order([ $product->id ])->id,
                        'putaway'
                    );
            }
        }, {
            'name'  => 'Quarantined items -> main stock',
            'setup' => sub {$from_faulty->(@_, 'stock')},
            'error' => $outstanding_error_regex
        }, {
            'name'  => 'Quarantined items -> dead stock',
            'setup' => sub {$from_faulty->(@_, 'dead')},
            'error' => $outstanding_error_regex
        },
    ) {
        subtest "Outstanding PIDs: " . $scenario->{'name'} => sub {
            # Create the test product
            my ($product) = Test::XTracker::Data->create_test_products({
                how_many => 1,
                channel_id => $source_channel->id,
                storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
            });

            # Make sure we're logged in - some of the setups call mech functions
            $self->{framework}->login_with_permissions({
                perms => { $AUTHORISATION_LEVEL__MANAGER => [
                    'Stock Control/Inventory',
                    'Stock Control/Channel Transfer',
                    'Stock Control/Quarantine',
                ]},
                dept => 'Stock Control'
            });

            # Get the stock process groups
            my @sp = $scenario->{setup}->($self, $product);

            # Try the channel transfer we're expecting to fail
            my $transfer = $self->{'framework'}->flow_task__stock_control__channel_transfer_auto({
                product      => $product,
                channel_from => $source_channel,
                channel_to   => Test::XTracker::Data->channel_for_out,
                schema       => $self->{'schema'},
                expect_error => $scenario->{error}
            });

            # Once we get a stock-received message, we should be ready to go
            $self->{framework}->flow_wms__send_stock_received(
                sp       => $_,
                operator => $self->{framework}->mech->logged_in_as_object,
            ) foreach @sp;

            # then expect it to transfer OK
            $self->{'framework'}->flow_task__stock_control__channel_transfer_auto({
                product      => $product,
                channel_from => $source_channel,
                channel_to   => Test::XTracker::Data->channel_for_out,
                schema       => $self->{'schema'},
                transfer     => $transfer
            });
        };
    }
}


sub call_channel_transfer {
    my ( $self, $args ) = @_;

    my $product = $args->{product};
    my @channels = @{$args->{channels}};
    my $source_channel = shift @channels;
    my $dest_channel = shift @channels;
    my $stop_after_selection = $args->{stop_after_selection};

    my @transfers;
    subtest join( q{},
        'Transfer ',
        $source_channel->business->config_section,
        '->',
        $dest_channel->business->config_section,
    ) => sub {
        if ($self->{automatic}) {
            push @transfers,
                $self->{'framework'}->flow_task__stock_control__channel_transfer_auto({
                    product => $product,
                    channel_from => $source_channel,
                    channel_to   => $dest_channel,
                    schema => $self->{'schema'},
                    stop_after_selection => $stop_after_selection,
                    prl_loc => $self->{'prl_loc'},
                });
        } else {
            my $location_rs = $self->{'schema'}->resultset('Public::Location');
            my %xfer_loc = (
                src => { channel => $source_channel },
                dst => { channel => $dest_channel },
            );
            for my $key (reverse sort keys %xfer_loc) {
                # use business ID to use unique location per business
                $xfer_loc{$key}{business_id} = $xfer_loc{$key}{channel}->business_id;
                # need to put Outnet stock on different floor
                $xfer_loc{$key}{is_outnet} = $xfer_loc{$key}{business_id} == Test::XTracker::Data->channel_for_out->business_id;
                # find suitable location
                $xfer_loc{$key}{location} = $location_rs->get_locations({
                        floor => 1,
                    })
                    ->slice($xfer_loc{$key}{business_id},$xfer_loc{$key}{business_id})
                    ->single;
                note "Using $key location ".$xfer_loc{$key}{location}->location.' for '.$xfer_loc{$key}{channel}->business->config_section;
            }
            push @transfers,
                $self->{'framework'}->flow_task__stock_control__channel_transfer_phase_0({
                    product => $product,
                    channel_from => $source_channel,
                    channel_to   => $dest_channel,
                    schema => $self->{'schema'},
                    src_location => $xfer_loc{src}{location}->location,
                    dst_location => $xfer_loc{dst}{location}->location,
                });
        }
    };

    if ( @channels ) {
        push @transfers, $self->call_channel_transfer({
            product => $product,
            stop_after_selection => $stop_after_selection,
            channels => [$dest_channel, @channels]
        });
    }

    return @transfers;
}
