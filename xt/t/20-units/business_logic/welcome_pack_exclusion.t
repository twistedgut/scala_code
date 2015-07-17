#!/usr/bin/env perl
use NAP::policy     qw( tt test );

=head1 NAME

welcome_pack_exclusion.t - Test Welcome Packs not being Added

=head1 DESCRIPTION

Tests that Welcome Packs are Excluded from being added to Orders
when the Items are all of a particular Product Type(s) that are
specified in the System Config.

=cut

use Test::XTracker::Data;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
    :shipment_item_status
    :stock_order_status
    :shipment_status
);
use XTracker::Database::Order;
use XTracker::Promotion::Pack qw( check_promotions );
use XT::Business;

use Test::XTracker::Mock::Service::Seaview;


my $schema  = Test::XTracker::Data->get_schema;
my $dbh     = $schema->storage->dbh;
my $business_logic = XT::Business->new({ });

my $channel_rs = Test::XTracker::Data->get_enabled_channels();
my $nap = Test::XTracker::Data->channel_for_business(name => 'nap');
my $out = Test::XTracker::Data->channel_for_business(name => 'outnet');
my $mrp = Test::XTracker::Data->channel_for_business(name => 'mrp');

$schema->txn_do( sub {
    run_tests();

    # rollback any changes
    $schema->txn_rollback;
} );
done_testing;


sub run_tests {
    # create a new Language that doesn't have
    # any Welcome Packs assigned to it
    $schema->resultset('Public::Language')->create( {
        code        => 'zz',
        description => 'Test Language, created by: ' . $0,
    } );

    my ( $excluded_prod_type, $included_prod_type ) = $schema->resultset('Public::ProductType')
                                                                ->search( {
        product_type => { '!=' => 'Unknown' },
    }, { rows => 2 } )->all;

    my $account_urn = Test::XTracker::Mock::Service::Seaview->make_up_resource_urn('account','TEST_CUST_ACC_URN');

    my %channel_expected = (
        $nap->id => {
            "Order Contains All Excluded Product Types & Has Seaview Account & Hasn't Been Sent a Welcome Pack Before" => {
                setup => {
                    account_urn    => $account_urn,
                    pid_prod_types => [ $excluded_prod_type, $excluded_prod_type ],
                    wp_flag        => 0,
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "Order Contains All Included Product Types & Has Seaview Account & Hasn't Been Sent a Welcome Pack Before" => {
                setup => {
                    account_urn    => $account_urn,
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                    wp_flag        => 0,
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "Order Contains Mix of Included & Excluded Product Types & Has Seaview Account & Hasn't Been Sent a Welcome Pack Before" => {
                setup => {
                    account_urn    => $account_urn,
                    pid_prod_types => [ $included_prod_type, $excluded_prod_type ],
                    wp_flag        => 0,
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "Order Contains All Included Product Types & Has Seaview Account & Has Been Sent a Welcome Pack Before" => {
                setup => {
                    account_urn    => $account_urn,
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                    wp_flag        => 1,
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "Order Contains Mix of Included & Excluded Product Types & Has Seaview Account & Has Been Sent a Welcome Pack Before" => {
                setup => {
                    account_urn    => $account_urn,
                    pid_prod_types => [ $included_prod_type, $excluded_prod_type ],
                    wp_flag        => 1,
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "Order Contains All Excluded Product Types & Doesn't Have a Seaview Account" => {
                setup => {
                    account_urn    => undef,
                    pid_prod_types => [ $excluded_prod_type, $excluded_prod_type ],
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "Order Contains All Included Product Types & Doesn't Have a Seaview Account" => {
                setup => {
                    account_urn    => undef,
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "Order Contains Mix of Included & Excluded Product Types & Doesn't Have a Seaview Account" => {
                setup => {
                    account_urn    => undef,
                    pid_prod_types => [ $included_prod_type, $excluded_prod_type ],
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "Order for Included Product Types, Doesn't have Seaview Account & is Customer's 3rd Order but NO Welcome Packs have previously been sent" => {
                setup => {
                    account_urn    => undef,
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                    create_previous_orders          => 2,
                    previous_order_had_welcome_pack => 0,
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "Order for Included Product Types, Doesn't have Seaview Account & is Customer's 3rd Order & HAS had a Welcome Packs sent previously" => {
                setup => {
                    account_urn    => undef,
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                    create_previous_orders          => 2,
                    previous_order_had_welcome_pack => 1,
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "When there are No Excluded Product Types for the Sales Channel and with a Seaview Account & welcomePackSent flag is FALSE" => {
                setup => {
                    account_urn    => $account_urn,
                    pid_prod_types => [ $excluded_prod_type, $excluded_prod_type ],
                    wp_flag        => 0,
                    dont_have_excluded_products => 1,
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "When there are No Excluded Product Types for the Sales Channel and without a Seaview Account" => {
                setup => {
                    account_urn    => undef,
                    pid_prod_types => [ $excluded_prod_type, $excluded_prod_type ],
                    dont_have_excluded_products => 1,
                },
                expect => {
                    welcome_pack => 1,
                },
            },
        },
        $out->id => {
            # OUTNET doesn't have Welcome Packs
            "Order Contains All Excluded Product Types" => {
                setup => {
                    pid_prod_types => [ $excluded_prod_type, $excluded_prod_type ],
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "Order Contains All Included Product Types" => {
                setup => {
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "Order Contains Mix of Included & Excluded Product Types" => {
                setup => {
                    pid_prod_types => [ $included_prod_type, $excluded_prod_type ],
                },
                expect => {
                    welcome_pack => 0,
                },
            },
        },
        $mrp->id => {
            # MRP Doesn't use Seaview to check for a Welcome Pack Flag
            "Order Contains All Excluded Product Types" => {
                setup => {
                    pid_prod_types => [ $excluded_prod_type, $excluded_prod_type ],
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "Order Contains All Included Product Types" => {
                setup => {
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "Order Contains Mix of Included & Excluded Product Types" => {
                setup => {
                    pid_prod_types => [ $included_prod_type, $excluded_prod_type ],
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "Order for Included Product Types & is Customer's 3rd Order but NO Welcome Packs have previously been sent" => {
                setup => {
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                    create_previous_orders          => 2,
                    previous_order_had_welcome_pack => 0,
                },
                expect => {
                    welcome_pack => 1,
                },
            },
            "Order for Included Product Types & is Customer's 3rd Order & HAS had a Welcome Packs sent previously" => {
                setup => {
                    pid_prod_types => [ $included_prod_type, $included_prod_type ],
                    create_previous_orders          => 2,
                    previous_order_had_welcome_pack => 1,
                },
                expect => {
                    welcome_pack => 0,
                },
            },
            "When there are No Excluded Product Types for the Sales Channel" => {
                setup => {
                    account_urn    => undef,
                    pid_prod_types => [ $excluded_prod_type, $excluded_prod_type ],
                    dont_have_excluded_products => 1,
                },
                expect => {
                    welcome_pack => 1,
                },
            },
        },
    );

    foreach my $channel ( $channel_rs->all ) {
        next if $channel->is_fulfilment_only;

        my $pids = create_products($channel, 2);

        my $customer_id;
        my $tests = $channel_expected{ $channel->id };

        note "TESTING for Sales Channel: " . $channel->name;

        foreach my $label ( keys %{ $tests } ) {
            note "Testing: ${label}";
            my $test = $tests->{ $label };

            my $setup  = $test->{setup};
            my $expect = $test->{expect};

            # set-up the Product Types for the PIDs
            $pids->[0]{product}->update( { product_type_id => $setup->{pid_prod_types}[0]->id } );
            $pids->[1]{product}->update( { product_type_id => $setup->{pid_prod_types}[1]->id } );

            Test::XTracker::Mock::Service::Seaview->set_welcome_pack_flag( $setup->{wp_flag} );

            if ( $setup->{dont_have_excluded_products} ) {
                _turn_on_welcome_packs();
            }
            else {
                _turn_on_welcome_packs( { exclude_product_type => $excluded_prod_type } );
            }

            $customer_id = my_create_customer( {
                channel_id  => $channel->id,
                account_urn => $setup->{account_urn},
            } );

            # create any Previous Orders that have been asked for
            if ( my $num_orders_to_create = $setup->{create_previous_orders} ) {
                my @orders;
                for ( 1..$num_orders_to_create ) {
                    push @orders, my_create_order( {
                        customer_id => $customer_id,
                        channel     => $channel,
                        pids        => $pids,
                        dont_try_to_assign_welcome_pack => 1,
                    } );
                }
                if ( $setup->{previous_order_had_welcome_pack} ) {
                    # assign a Welcome Pack to the first
                    # Order created above if asked to do so
                    _assign_welcome_pack_to_order( $orders[0] );
                }
            }

            Test::XTracker::Mock::Service::Seaview->clear_recent_account_update_request;

            # now create the Order to test with
            my $order = my_create_order( {
                customer_id => $customer_id,
                channel     => $channel,
                pids        => $pids,
            } );

            my $promotions  = get_order_promotions( $dbh, $order->id) ;
            my @wp_promos   = extract_wp( $promotions );

            if ( $expect->{welcome_pack} ) {
                cmp_ok( @wp_promos, '==', 1, "Found 1 Welcome Pack attached to the Order" );
                if ( $setup->{account_urn} ) {
                    # set-the Welcome Flag Sent flag to TRUE so
                    # the subsequent Order test below should pass
                    Test::XTracker::Mock::Service::Seaview->set_welcome_pack_flag( 1 );
                    my $account = Test::XTracker::Mock::Service::Seaview->get_recent_account_update;
                    isa_ok( $account, 'HASH', "an Account Update was made to Seaview" );
                    is(
                        # stringfy the JSON::PP::Boolean to either 1 or 0
                        qq/$account->{welcomePackSent}/,
                        '1',
                        "and 'welcomePackSent' flag has been set to TRUE"
                    );
                }
            }
            else {
                cmp_ok( @wp_promos, '==', 0,
                    $channel->name . " - Didn't Get a Welcome Pack" );
                my $account = Test::XTracker::Mock::Service::Seaview->get_recent_account_update;
                ok( !defined $account, "no Account Update was made to Seaview" );
            }

            # test that subsequent Orders for the same
            # Customer don't get assigned a Welcome Pack
            $order = my_create_order({
                customer_id => $customer_id,
                channel     => $channel,
                pids        => $pids,
            });
            $promotions = get_order_promotions($dbh, $order->id);
            cmp_ok( scalar extract_wp($promotions), q{==}, 0,
                        'Subsequent Orders have NO Welcome Packs on ' . $channel->name );
        }
    }
}

sub extract_wp {
    my($promos) = @_;
    my @wps;
    foreach my $key (keys %{$promos}) {
        push @wps, $promos->{ $key }
            if ($promos->{$key}->{name} =~ /^Welcome Pack/i);
    }
    return @wps;
}

sub create_products {
    my ( $channel, $how_many ) = @_;

    # Create products on the given channel. As create_db_order relies on
    # find_products output (called by grab_products in this case), and we're
    # using create_from_hash, we need to fake its output for create_db_order
    # to work.
    my $p_ref = {
        product_channel => [{
            channel_id  => $channel->id,
            upload_date => \'now()',
            live        => 1,
            visible     => 1,
        }],
    };
    my $purchase_order = Test::XTracker::Data->create_from_hash({
        channel_id  => $channel->id,
        stock_order => [map { product => $p_ref }, 1..$how_many],
    });
    # Fake find/grab_products output... nice
    my $pc_rs = $purchase_order->stock_orders
                                ->related_resultset('public_product')
                                ->search_related('product_channel',
                                    {channel_id => $channel->id}
                                );
    my @pids;
    while ( my $pc = $pc_rs->next ) {
        my $variant = $pc->product->variants->slice(0,0)->single;
        push @pids, {
            pid             => $pc->product_id,
            size_id         => $variant->size_id,
            sku             => $variant->sku,
            variant_id      => $variant->id,
            product         => $pc->product,
            variant         => $variant,
            product_channel => $pc,
        };
    }
    die "Couldn't find $how_many pid(s)" unless $how_many == @pids;
    return \@pids;
}

# creates a Customer
sub my_create_customer {
    my $args    = shift;

    my $customer_id = Test::XTracker::Data->create_test_customer(
        channel_id  => $args->{channel_id},
        account_urn => $args->{account_urn},
    );

    my $customer = $schema->resultset('Public::Customer')
                            ->find( $customer_id );

    return $customer_id;
}

# creates an order
sub my_create_order {
    my $args = shift;

    my ( $customer_id, $country_name, $channel, $pids )
        = @{ $args }{ qw/customer_id country_name channel pids/ };

    my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => {
            customer_id => $customer_id,
            channel_id  => $channel->id,
            order_status_id => $STOCK_ORDER_STATUS__ON_ORDER,
            shipment_status => $SHIPMENT_STATUS__PROCESSING,
            shipment_item_status => $SHIPMENT_ITEM_STATUS__PICKED,
        },
        attrs => [
            {
                price => 100.00,
                shipment_item_status => $SHIPMENT_ITEM_STATUS__PICKED,
            },
            {
                price => 250.00,
                shipment_item_status => $SHIPMENT_ITEM_STATUS__PICKED,
            },
        ],
    });

    # if only an Order was wanted then just return it
    return $order   if ( $args->{dont_try_to_assign_welcome_pack} );

    XTracker::Promotion::Pack->check_promotions(
        $schema, $order, instantiate_plugin($order)
    );

    return $order;
}

sub instantiate_plugin {
    my($order) = @_;
    return $business_logic->find_plugin(
        $order->channel,'OrderImporter');
}

# turn on Welcome Packs in the System Config
sub _turn_on_welcome_packs {
    my $args = shift;

    my $groups  = $schema->resultset('SystemConfig::ConfigGroup')
                            ->search( { name => 'Welcome_Pack' } );

    # get a list of the settings used for
    # languages so that they can be turned on
    my @language_settings = map { $_->code } $schema->resultset('Public::Language')->all;
    # add 'DEFAULT' which is used by some Channels
    push @language_settings, 'DEFAULT';

    # Activate at Group level
    $groups->update( { active => 1 } );
    # Activate each Setting
    $groups->search_related('config_group_settings')
            ->update( {
        active => 1,
    } );

    # turn on all Languages
    $groups->search_related('config_group_settings', { setting => { 'IN' => \@language_settings } } )
            ->update( {
        value => 'On',
    } );

    # remove any Product Type restrictions
    $groups->search_related('config_group_settings', { setting => 'exclude_on_product_type' } )
            ->delete;
    if ( my $product_type = $args->{exclude_product_type} ) {
        # add Product Type restrictions
        foreach my $group ( $groups->all ) {
            # create a Product Type to Exclude
            $group->search_related('config_group_settings')
                    ->create( { setting => 'exclude_on_product_type', value => $product_type->product_type } );
        }
    }

    return;
}

# helper to assign a Welcome Pack to an Order
sub _assign_welcome_pack_to_order {
    my $order = shift;

    # get the English Welcome Pack which should be
    # present on any Channel that has Welcome Packs
    my $pack = $order->channel->find_welcome_pack_for_language('en');

    $order->create_related( 'order_promotions', {
        promotion_type_id   => $pack->id,
        value               => 0,
        code                => 'none',
    } );

    return;
}

