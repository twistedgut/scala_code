#!/usr/bin/env perl
use NAP::policy     qw( tt test );

=head1 NAME

welcome_pack.t - Language Welcome Packs

=head1 DESCRIPTION

Tests that the correct Language Welcome Packs
are added to Orders.

=cut

use Test::XTracker::Data;
use Test::XTracker::Mock::Service::Seaview;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
    :shipment_item_status
    :stock_order_status
    :shipment_status
);
use XTracker::Database::Order;
use XTracker::Promotion::Pack qw( check_promotions );
use XT::Business;


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

    _turn_on_welcome_packs();

    my $default_language_code   = config_var('Customer', 'default_language_preference');

    my %channel_expected = (
        $nap->id => {
            no_wp => {
                language => 'zz',
                wp_name => undef,
            },
            non_en_wp => {
                language => 'fr',
                wp_name => $nap->find_welcome_pack_for_language('fr')->name,
            },
            en_wp => {
                language => 'en',
                wp_name => $nap->find_welcome_pack_for_language('en')->name,
            },
        },
        $out->id => {
            # OUTNET doesn't have Welcome Packs
            no_wp => {
                language => 'zz',
                wp_name => undef,
            },
            non_en_wp => {
                language => 'fr',
                wp_name => undef,
            },
            en_wp => {
                language => 'en',
                wp_name => undef,
            },
        },
        $mrp->id => {
            # in MRP all Language packs are the DEFAULT
            no_wp => {
                language => 'zz',
                wp_name => $mrp->find_welcome_pack_for_language( $default_language_code )->name,
            },
            non_en_wp => {
                language => 'fr',
                wp_name => $mrp->find_welcome_pack_for_language( $default_language_code )->name,
            },
            en_wp => {
                language => 'en',
                wp_name => $mrp->find_welcome_pack_for_language( $default_language_code )->name,
            },
        },
    );
    for my $channel ( $channel_rs->all ) {
        next if $channel->is_fulfilment_only;

        my $pids = create_products($channel, 2);

        my $customer_id;
        my $expected = $channel_expected{ $channel->id };

        foreach my $test ( keys %{ $expected } ) {
            note "Test Key: ${test}";
            my $value = $expected->{$test};

            # set some defaults for fake Seaview
            Test::XTracker::Mock::Service::Seaview->clear_recent_account_update_request;
            Test::XTracker::Mock::Service::Seaview->set_welcome_pack_flag(0);

            $customer_id = my_create_customer( {
                channel_id  => $channel->id,
                language    => $value->{language},
            } );
            my $order = my_create_order({
                customer_id => $customer_id,
                channel     => $channel,
                pids        => $pids,
            });
            my $promotions  = get_order_promotions($dbh, $order->id);
            my @wp_promos   = extract_wp( $promotions );

            if ( defined $value->{wp_name} ) {
                cmp_ok( @wp_promos, '==', 1, "Found 1 Welcome Pack attached to the Order" );
                is( $wp_promos[0]{name}, $value->{wp_name},
                    $channel->name . " Customers with CPL of '$value->{language}' receive '$value->{wp_name}'");
            }
            else {
                cmp_ok( @wp_promos, '==', 0,
                    $channel->name . " Customers with CPL of '$value->{language}' receive 'nothing'");
            }

            # get the last Account update and set the
            # 'welcomePackSent' flag for the next test
            my $account = Test::XTracker::Mock::Service::Seaview->get_recent_account_update;
            if ( $account ) {
                Test::XTracker::Mock::Service::Seaview->set_welcome_pack_flag(
                    $account->{welcomePackSent},
                );
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
                        'Subsequent Orders have NO Welcome Packs on ' . $channel->name )
                                or diag "Promotions Found: " . p( $promotions );
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
    );

    my $customer = $schema->resultset('Public::Customer')
                            ->find( $customer_id );

    $customer->set_language_preference( $args->{language} );

    return $customer_id;
}

# creates an order
sub my_create_order {
    my ($customer_id, $country_name, $channel, $pids)
        = @{$_[0]}{qw/customer_id country_name channel pids/};

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
    note 'View the WP shipment page: http://localhost/Fulfilment/Packing/PackShipment?shipment_id='
       . $order->shipments->first->id;

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

    my $groups  = $schema->resultset('SystemConfig::ConfigGroup')
                            ->search( { name => 'Welcome_Pack' } );

    # Activate at Group level
    $groups->update( { active => 1 } );
    # Activate each Setting
    $groups->search_related( 'config_group_settings' )
            ->update( {
        value  => 'On',
        active => 1,
    } );

    return;
}

