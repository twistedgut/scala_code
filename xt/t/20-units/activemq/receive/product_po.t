package Test::XTracker::ActiveMQ::Receive::ProductPO;
use NAP::policy "tt", 'test';
use base 'Test::Class';
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use Test::XTracker::Hacks::TxnGuardRollback;
use XTracker::Config::Local qw( config_var );
use DateTime;
use Time::HiRes 'time';
use XTracker::Constants::FromDB qw( :channel :variant_type );
use XTracker::Constants qw( :application :message_response );
use Sys::Hostname;
use Const::Fast;

const my $ARBITRARY_NUMBER_THAT_WILL_BE_IGNORED => 453267;

my $DC = Test::XTracker::Data->whatami();
my $count = 0;

my $placed_pos;

sub startup : Tests(startup => 2) {
    my ( $self ) = @_;
    ($self->{amq},$self->{app}) = Test::XTracker::MessageQueue->new_with_app;
    $self->{schema} = XT::DC::Messaging->model('Schema');
    $self->{txn_guard} = $self->{schema}->storage->txn_scope_guard;
    $self->{default_date} = '2010-06-02T17:14:34';
    $self->{broadcast_destination}
        = config_var('Producer::Stock::DetailedLevelChange', 'destination');
}

sub teardown : Tests(teardown => 0) {
    my $self = shift;
    $self->{txn_guard}->rollback;
    #$self->{amq}->clear_destination( $self->{broadcast_destination} );
}

sub setup : Test(setup => 1) {
    my ( $self ) = @_;

    my $supplier_code = 'foo';
    $self->{schema}->resultset('Public::Supplier')->find_or_create({
        code => 'foo',
        description => 'test supplier',
    });
    my ($designer_name) = $self->designer_name;

    my $date = $self->{default_date};
    my @channels = Test::XTracker::Data->get_enabled_channels->all;
    for my $channel ( @channels ) {
        my @products = Test::XTracker::Data->create_test_products({
            how_many => 2, channel_id => $channel->id, dont_ensure_stock => 1,
        });

        # this allows us to be certain of the "on order" quantities
        for my $p (@products) {
            $p->delete_related_stock_order_items;
        }

        $self->{test_data}{$channel->name} = {
            products => \@products,
            channel => $channel,
        };
        note '________________________________________________________';
        $self->{test_data}{$channel->name}{po_params} = {
            act => 'Main',
            channel_id => $channel->id,
            confirmed_by => undef,
            created_by => 'test operator',
            date => $date,
            designer => $designer_name,
            payment_deposit => '0',
            payment_settlement_discount => '0',
            payment_term => 'Immediate',
            po_number => 'POTESTNUMBER'.time().'-'.$$.'-'.(++$count),
            season => 'CR07',
            ship_origin => 'test script',
            status => 'Placed',
            stock => [ ],
            supplier => $supplier_code,
        };

        # Add a rouge variant to one of the two products (a variant not in
        # the specified size scheme).
        #
        # This is to test some legacy fallback behaviour (see
        # comment "This is the bad old way" at Consumer::PurchaseOrder #346)
        #
        # I think we are not using this fallback behaviour but want to cover it
        # in the test suite until we are sure (was previously being covered or
        # not randomly based on test data setup...)
        my $one_size = $self->{schema}->resultset('Public::Size')->find({ size => 'One size'});
        $self->{schema}->resultset('Public::Variant')->create({
            id => Test::XTracker::Data->next_id('variant'),
            size_id => $one_size->id,
            type_id => $VARIANT_TYPE__STOCK,
            designer_size_id => $one_size->id,
            product_id => $products[1]->id,
        });

        for my $p (@products) {
            my $stock_params = {
                cancel_ship_date => $date,
                items => [ ],
                product_id => $p->id,
                shipment_window_type => 'Ex Factory',
                size_scheme => $p->attribute->size_scheme->name,
                start_ship_date => $date,
            };
            if ( $channel->is_on_outnet ) {
                # Delete any existing markdowns and define a new one
                # With the current business all products that are imported at
                # this stage should be new and we should never get pids that
                # already have related price adjustment rows, so for the
                # purposes of this test it's safe to delete these.

                # TODO: What to do when we are passing a confirm/cancel po
                # message with new markdown data?
                $p->price_adjustments->delete;
                $stock_params->{markdown} = {
                    category => '1st MD',
                    percentage => 50,
                    start_date => $date,
                }
            }

            for my $v ($p->variants) {
                push @{$stock_params->{items}},{
                    quantity => 1,
                    size => $v->size->size,
                    # remove variant_id when fulcrum stops sending them
                    variant_id => $ARBITRARY_NUMBER_THAT_WILL_BE_IGNORED,
                };
            }

            push @{$self->{test_data}{$channel->name}{po_params}{stock}},$stock_params;
        }
    }

    $self->{amq}->clear_destination( $self->{broadcast_destination} );
    $self->{amq}->clear_destination( '/topic/purchase-order-info' );
}

sub designer_name {
    my ( $self ) = @_;
    return $self->{schema}->storage->dbh_do(sub{
        my ($storage, $dbh) = @_;
        my $d = $dbh->selectall_arrayref(<<'_SQL_');
SELECT designer
FROM designer
WHERE designer NOT ILIKE 'unk%'
AND designer NOT ILIKE 'none'
LIMIT 1
_SQL_
        die "No designer" if not $d->[0];
        return $d->[0][0];
    });
}

sub test_create_po : Tests {
    my ( $self ) = @_;
    my $schema = $self->{schema};

    for my $test ( keys %{$self->{test_data}} ) {

        $self->{amq}->clear_destination( $self->{broadcast_destination} );
        $self->{amq}->clear_destination( '/topic/purchase-order-info' );

        my $data = $self->{test_data}{$test};

        my $res = $self->{amq}->request(
            $self->{app},
            "/queue/$DC/product",
            $data->{po_params},
            { type => 'purchase_order' },
        );
        ok( $res->is_success, 'Create message processed successfully' ) or diag $res->content;

        my $size_name = $data->{po_params}->{stock}->[1]->{items}->[1]->{size};
        my $product_id = $data->{po_params}->{stock}->[1]->{product_id};
        my $variant = $self->{schema}->resultset('Public::Variant')->search({
            product_id => $product_id,
            'size.size' => $size_name,
            type_id => $VARIANT_TYPE__STOCK,
        },
        {
            join => 'size',
        })->single;
        my $vid = $variant->id;


        $self->{amq}->assert_messages({
            destination => $self->{broadcast_destination},
            filter_header => superhashof({
                type => 'DetailedStockLevelChange',
            }),
            filter_body => superhashof({
                variants => superbagof(superhashof({
                    variant_id => $vid,
                })),
            }),
            assert_body => superhashof({
                variants => superbagof(superhashof({
                    levels => superhashof({
                        on_order_quantity => 1,
                        total_ordered_quantity => 1,
                    }),
                })),
            }),
        });

        my $po = $schema->resultset('Public::PurchaseOrder')->find({
            purchase_order_number => $data->{po_params}{po_number}
        });
        isa_ok($po,'XTracker::Schema::Result::Public::PurchaseOrder');

        is( $po->channel_id, $data->{channel}->id, 'correct channel' );
        is( $po->act->act, 'Main', 'correct act' );
        ok( !$po->confirmed, 'not confirmed' );
        is( $po->date->iso8601, $self->{default_date}, 'correct date' );
        is( $po->stock_orders->count, 2, 'correct # of rows' );

        my $prod = $data->{po_params}{stock}[0];
        my $so = $po->search_related('stock_orders',
            { product_id => $prod->{product_id} },
            { rows => 1 },
        )->first;
        is( $so->cancel_ship_date->iso8601, $self->{default_date}, 'correct SO date' );
        is( $so->stock_order_items->count, scalar(@{$prod->{items}}), 'correct # of variants' );

        my $v = $so->stock_order_items->first;
        is($v->quantity,1,'correct quantity');

        SKIP: {
            skip sprintf( "skipping marked down products for %s", $po->channel->name ), 4
                unless $po->channel->is_on_outnet;

            ok( my $md = $so->product->current_markdown, 'product has markdown' );
            my $expected_md = $prod->{markdown};
            is( $md->category->category, $expected_md->{category},
                'markdown category ok' );
            cmp_ok( $md->percentage, q{==}, $expected_md->{percentage},
                'markdown percentage ok' );
            is( $md->date_start->iso8601, $expected_md->{start_date},
                'markdown start date ok' );
        }

        push @$placed_pos, $po->purchase_order_number;
        # Testing if the a success message was placed into the amq
        $self->{amq}->assert_messages({
            destination => '/topic/purchase-order-info',
            assert_header => superhashof({
                type => 'po_imported',
            }),
            assert_body => superhashof({
                po_number => $po->purchase_order_number,
                status => $MESSAGE_RESPONSE_STATUS_SUCCESS,
                '@type' => 'po_imported',
            }),
        },'po success message sent');
    }
}

sub test_cancel_po : Tests {
    my ( $self ) = @_;
    my $schema = $self->{schema};

    for my $test ( keys %{$self->{test_data}} ) {
        my $data = $self->{test_data}{$test};
        my $res = $self->{amq}->request(
            $self->{app},
            "/queue/$DC/product",
            $data->{po_params},
            { type => 'purchase_order' },
        );
        ok( $res->is_success, 'Create message processed ok' );

        $self->{amq}->clear_destination( $self->{broadcast_destination} );

        $data->{po_params}{status}='Cancelled';

        $res = $self->{amq}->request(
            $self->{app},
            "/queue/$DC/product",
            $data->{po_params},
            { type => 'purchase_order' },
        );
        ok( $res->is_success, 'Cancel message processed ok' );

        my $po = $schema->resultset('Public::PurchaseOrder')->find(
            {purchase_order_number => $data->{po_params}{po_number} }
        );
        isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder' );

        ok( !$po->confirmed, 'not confirmed' );
        ok( $po->cancel, 'cancelled');

        foreach my $so ( $po->stock_orders ) {
            # When a po is cancelled, the stock_order_cancel flag should not be set.
            ok( !$so->stock_order_cancel, 'Stock order cancel flag is set');
            # When a po is cancelled the cancel flag on the stock order should be set.
            ok( $so->cancel, 'Cancel flag in stock order is set');
            foreach my $soi ( $so->stock_order_items ) {
                ok( $soi->cancel, 'Cancel flag in stock order items set to true');
                ok( !$soi->stock_order_item_cancel,
                    'Stock order item cancel flag set to false');
            }
        }

        my @pids = map { $_->{product_id} } @{$data->{po_params}{stock}};

        $self->{amq}->assert_messages({
            destination => $self->{broadcast_destination},
            assert_header => superhashof({
                type => 'DetailedStockLevelChange',
            }),
            assert_body => superhashof({
                channel_id => $po->channel_id,
                product_id => any(@pids),
                variants => array_each(superhashof({
                    levels => superhashof({
                        on_order_quantity => 0,
                    }),
                })),
            }),
            assert_count => scalar @pids,
        },'stock messages sent');
    }
}

sub test_cancel_uncancel_po : Test(42) {
    my ( $self ) = @_;

    my $schema = $self->{schema};

    for my $test ( keys %{$self->{test_data}} ) {
        subtest 'test cancel and uncancel_po foreach test loop' => sub {
            plan tests => 25;

            my $data = $self->{test_data}{$test};
            my $res = $self->{amq}->request(
                $self->{app},
                "/queue/$DC/product",
                $data->{po_params},
                { type => 'purchase_order' },
            );
            ok( $res->is_success, 'Create purchase order message processed successfully' );

            $self->{amq}->clear_destination( $self->{broadcast_destination} );

            # Set status of PO to cancelled.
            $data->{po_params}{status}='Cancelled';

            # Set a specific stock_order to cancelled before we send message
            # to cancel whole PO.
            $res = $self->{amq}->request(
                $self->{app},
                "/queue/$DC/product",
                $data->{po_params},
                { type => 'purchase_order' },
            );

            ok( $res->is_success, 'Cancel purchase order message processed successfully' );

            my $po = $schema->resultset('Public::PurchaseOrder')->find(
                {purchase_order_number => $data->{po_params}{po_number} }
            );

            isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder' );
            ok( !$po->confirmed, sprintf('po %s is not confirmed', $data->{po_params}{po_number} ));
            ok( $po->cancel, sprintf('po %s is cancelled', $data->{po_params}{po_number} ));

            my @pids = map { $_->{product_id} } @{$data->{po_params}{stock}};
            $self->{amq}->assert_messages({
                destination => $self->{broadcast_destination},
                assert_header => superhashof({
                    type => 'DetailedStockLevelChange',
                }),
                assert_body => superhashof({
                    channel_id => $po->channel_id,
                    product_id => any(@pids),
                    variants => array_each(superhashof({
                        levels => superhashof({
                            on_order_quantity => 0,
                        }),
                    })),
                }),
                assert_count => scalar @pids,
            },'stock messages sent');

            $self->{amq}->clear_destination( $self->{broadcast_destination} );
            # Uncancel the same PO
            $data->{po_params}{status}='Confirmed';
            $res = $self->{amq}->request(
                $self->{app},
                "/queue/$DC/product",
                $data->{po_params},
                { type => 'purchase_order' },
            );

            ok( $res->is_success, 'Uncancel message processed successfully' );
            $po->discard_changes();

            isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder' );
            ok( $po->confirmed,  sprintf('po %s is confirmed', $data->{po_params}{po_number} ));

            ok( !$po->cancel, sprintf('po %s is not cancelled', $data->{po_params}{po_number} ));
            for my $so ( $po->stock_orders ) {
                ok( !$so->cancel, 'Cancel flag in stock order table is set to false');
                ok( !$so->stock_order_cancel, 'Stock order cancel flag is set to false');
                foreach my $soi ( $so->stock_order_items ) {
                    ok( !$soi->cancel, 'Cancel flag in stock order items set to false');
                    ok( !$soi->stock_order_item_cancel,
                        'Stock order item cancel flag set to false');
                }
            }

            @pids = map { $_->{product_id} } @{$data->{po_params}{stock}};
            $self->{amq}->assert_messages({
                destination => $self->{broadcast_destination},
                assert_header => superhashof({
                    type => 'DetailedStockLevelChange',
                }),
                assert_body => superhashof({
                    channel_id => $po->channel_id,
                    product_id => any(@pids),
                    variants => array_each(superhashof({
                        levels => superhashof({
                            on_order_quantity => 1,
                        }),
                    })),
                }),
                assert_count => scalar @pids,
            },'stock messages sent');
        };
    }
}


sub test_confirm_po : Test(20) {
    my ( $self ) = @_;
    my $schema = $self->{schema};

    for my $test ( keys %{$self->{test_data}} ) {
        my $data = $self->{test_data}{$test};
        my $res = $self->{amq}->request(
            $self->{app},
            "/queue/$DC/product",
            $data->{po_params},
            { type => 'purchase_order' },
        );
        ok( $res->is_success, 'Create message processed successfully' );

        $data->{po_params}{status}='Confirmed';

        $res = $self->{amq}->request(
            $self->{app},
            "/queue/$DC/product",
            $data->{po_params},
            { type => 'purchase_order' },
        );
        ok( $res->is_success, 'Cancel message processed successfully' );

        my $po = $schema->resultset('Public::PurchaseOrder')->find(
            { purchase_order_number => $data->{po_params}{po_number} }
        );
        isa_ok( $po, 'XTracker::Schema::Result::Public::PurchaseOrder' );

        ok( $po->confirmed,sprintf('po %s is confirmed', $data->{po_params}{po_number} ));
        ok( !$po->cancel, sprintf('po %s is not cancelled', $data->{po_params}{po_number} ));
    }
}

sub test_create_po_failure : Tests {
    my ( $self ) = @_;
    my $schema = $self->{schema};

    my $data = $self->{test_data}->{'NET-A-PORTER.COM'};

    # Forcing an already existing po number so it fails
    $data->{po_params}->{po_number} = $placed_pos->[0];

    # clear stock items to cause error on the message spec, before the actual transform kicks in,
    # so we would need to go on the DLQ to find it. This however doens't seem to be working well
    # in unit tests with the fake AMQ broker
    # for my $p (@{ $data->{po_params}->{stock} }) {
        #delete $p->{items};
    # }

    my $res = $self->{amq}->request(
        $self->{app},
        "/queue/$DC/product",
        $data->{po_params},
        { type => 'purchase_order' },
    );

    ok( $res->is_success, 'Create message processed successfully' ) or diag $res->content;

    $self->{amq}->assert_messages({
        destination => '/topic/purchase-order-info',
        assert_header => superhashof({
            type => 'po_imported',
        }),
        assert_body => superhashof({
            po_number => $data->{po_params}{po_number},
            error_id => re('XT-PO-IMPORT-ERROR-'),
            status => $MESSAGE_RESPONSE_STATUS_ERROR,
            '@type' => 'po_imported',
            message => "PO $data->{po_params}{po_number} already exists - can't recreate it\n",
            user_message => "XTracker encountered an error importing purchase order $data->{po_params}{po_number}",

        }),
        assert_count => 1,
    },'po reply sent');
}


Test::Class->runtests;
