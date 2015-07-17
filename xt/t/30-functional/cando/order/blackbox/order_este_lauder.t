#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use Test::More skip_all => 'This test uses the older order importer - it needs to be rewritten to use the new one or deleted (see CANDO-3155)';
use FindBin::libs;
use Test::Most '-Test::Deep';
use Data::Dump qw( pp );

use Test::XTracker::Data;
use XTracker::Config::Local qw/ sys_config_var /;
use Test::XTracker::Data::Order;
use XTracker::Promotion::Pack;
use Test::XTracker::RunCondition dc => 'DC2';
use Test::XT::Flow;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [qw<
        Test::XT::Data::Location
    >],
);
$framework->data__location__initialise_non_iws_test_locations;

=head2 Test Plan

- place an order with a brand new customer buying real products
    -> should get promotion
- place an order with an existing customer, not had promotion before
    -> should get promotion
- place an order with a customer whose had the promotion before
    -> shouldnt get promotion
- place an order with a customer only buying vouchers
    -> shouldnt get promotion
- place an order with customer buying both vouchers and products
    -> should get promotion

=cut

my $filename = 'NAP_AM_standard_order.xml.tt';
my $schema   = Test::XTracker::Data->get_schema();

my $channel_id = $schema->resultset('Public::Channel')
                    ->search( { web_name => 'NAP-AM' } )
                    ->first
                    ->id;

note '$channel_id = ' . $channel_id;

# delete all existing xml files in case of previously crashed test:
Test::XTracker::Data::Order->purge_order_directories();

test_new_customer_ok( $schema, $filename, $channel_id );
#test_existing_customer_not_had_promotion_ok( $schema, $filename, $channel_id );
test_customer_had_promotion_ok( $schema, $filename, $channel_id );
test_customer_only_buying_vouchers_ok( $schema, $filename, $channel_id );
test_customer_buying_vouchers_and_products_ok( $schema, $filename, $channel_id );

done_testing();

sub test_new_customer_ok {
    my ( $schema, $filename, $channel_id ) = @_;

    note pp $filename;

    my $dbh = $schema->storage->dbh;
    ## create a new customer
    my $new_customer_email =  Test::XTracker::Data->create_unmatchable_customer_email( $dbh );

    my $new_customer_id =  Test::XTracker::Data->create_test_customer(
        email       => $new_customer_email,
        channel_id  => $channel_id,
    );

    my $new_customer = $schema->resultset('Public::Customer')
        ->search( { id => $new_customer_id } )->first;

    note pp $new_customer->pws_customer_id;
    note pp $new_customer_email;

    my $order = Test::XTracker::Data->get_order_from_xml_ok( $filename, {
        customer => {
            email   => $new_customer_email,
            id      => $new_customer->pws_customer_id,
            customer_nr => $new_customer->is_customer_number,
        },
        order => { items => _items($channel_id) },
    } );

    check_promotion_ok($schema, $order->id);

}

sub test_existing_customer_not_had_promotion_ok {
    my ( $schema, $filename, $channel_id ) = @_;

    my $customer = Test::XTracker::Data->find_customer( { channel_id => $channel_id } );

    neto $customer->email;
    note $customer->id;

    my $order = Test::XTracker::Data->get_order_from_xml_ok( $filename, {
        customer => {
            email   => $customer->email,
            id      => $customer->id,
            customer_nr => $customer->is_customer_number,
        },
        order => { items => _items($channel_id) },
    } );

    check_promotion_ok( $schema, $order->id );
}

sub test_customer_had_promotion_ok {
    my ( $schema, $filename, $channel_id ) = @_;

    my $dbh = $schema->storage->dbh;
    ## create a new customer
    my $new_customer_email =  Test::XTracker::Data->create_unmatchable_customer_email( $dbh );

    my $new_customer_id =  Test::XTracker::Data->create_test_customer(
        email       => $new_customer_email,
        channel_id  => $channel_id,
    );

    my $new_customer = $schema->resultset('Public::Customer')
        ->search( { id => $new_customer_id } )->first;

    note pp $new_customer->pws_customer_id;
    note pp $new_customer_email;

    my $order = Test::XTracker::Data->get_order_from_xml_ok( $filename, {
        customer => {
            email   => $new_customer_email,
            id      => $new_customer->pws_customer_id,
            customer_nr => $new_customer->is_customer_number,
        },
        order => { items => _items($channel_id) },
    } );

    check_promotion_ok( $schema, $order->id );

    $order = undef;
    $order = Test::XTracker::Data->get_order_from_xml_ok( $filename, {
        customer => {
            email   => $new_customer_email,
            id      => $new_customer->pws_customer_id,
            customer_nr => $new_customer->is_customer_number,
        },
        order => { items => _items($channel_id) },
    } );

    check_promotion_ok( $schema, $order->id );

}

sub test_customer_only_buying_vouchers_ok {
    my ( $schema, $filename, $channel_id ) = @_;

    my $dbh = $schema->storage->dbh;

    my $pvoucher = Test::XTracker::Data->create_voucher();
    my $ol_id = $$;
    $filename = 'NAP_AM_voucher_este_orders.xml.tt';
    note $filename;
    # set-up the details for the order
    my $order_details  = {
        no_items => 1,
        shipping_price => 10,
        shipping_tax => 1.50,
        voucher_items => [
            {
                sku => $pvoucher->variant->sku,
                description => $pvoucher->name,
                ol_id => $ol_id,
                unit_price => $pvoucher->value,
                tax => 10,
                duty => 5,
                to => 'Recipient',
                from => 'Sender',
                message => 'Gift Message',
            }
        ],
    };

    print STDERR $pvoucher->variant->sku;

    my $new_customer_email =  Test::XTracker::Data->create_unmatchable_customer_email( $dbh );

    my $new_customer_id =  Test::XTracker::Data->create_test_customer(
        email       => $new_customer_email,
        channel_id  => $channel_id,
    );

    my $new_customer = $schema->resultset('Public::Customer')
        ->search( { id => $new_customer_id } )->first;

    my $order = Test::XTracker::Data->get_order_from_xml_ok( $filename, {
        customer => {
            email   => $new_customer_email,
            id      => $new_customer->pws_customer_id,
            customer_nr => $new_customer->is_customer_number,
        },
        order => $order_details,
    } );

    check_promotion_ok( $schema, $order->id );

}

sub test_customer_buying_vouchers_and_products_ok {
    my ( $schema, $filename, $channel_id ) = @_;

    my $dbh = $schema->storage->dbh;

    my $pvoucher = Test::XTracker::Data->create_voucher();
    my $ol_id = $$;
    $filename = 'NAP_AM_voucher_este_orders.xml.tt';
    note $filename;
    # set-up the details for the order
    my (undef,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        channel_id => $channel_id,
    });
    my $order_details  = {
        shipping_price => 10,
        shipping_tax => 1.50,
        voucher_items => [
            {
                sku => $pvoucher->variant->sku,
                description => $pvoucher->name,
                ol_id => $ol_id,
                unit_price => $pvoucher->value,
                tax => 10,
                duty => 5,
                to => 'Recipient',
                from => 'Sender',
                message => 'Gift Message',
            }
        ],
        items => [
            {
                sku => $pids->[0]{sku},
                description => "Suede thigh-high boots",
                unit_price => 691.30,
                tax => 48.39,
                duty => 0.00
            }
        ],
    };

    note $pvoucher->variant->sku;

    my $new_customer_email = Test::XTracker::Data->create_unmatchable_customer_email( $dbh );

    my $new_customer_id =  Test::XTracker::Data->create_test_customer(
        email       => $new_customer_email,
        channel_id  => $channel_id,
    );

    my $new_customer = $schema->resultset('Public::Customer')
        ->search( { id => $new_customer_id } )->first;

    my $order = Test::XTracker::Data->get_order_from_xml_ok( $filename, {
        customer => {
            email   => $new_customer_email,
            id      => $new_customer->pws_customer_id,
            customer_nr => $new_customer->is_customer_number,
        },
        order => $order_details,
    } );

    check_promotion_ok( $schema, $order->id );

}

sub check_promotion_ok {
    my ( $schema, $order_id ) = @_;

    my $dbh = $schema->storage->dbh;

    my $promotion_on = sys_config_var($schema, 'Promotions', 'Este Lauder') eq 'On';

    my $order = $schema->resultset('Public::Orders')->find($order_id);
    my $promo = $order->search_related('order_promotions',{
        'promotion_type.name' => 'Este Lauder Brochure',
    }, {
        join => 'promotion_type',
    });

    if ($promotion_on) {
        ok($promo->count, 'The Este Lauder Promotion was correctly applied' );
    }
    else {
         ok(!$promo->count, 'Este Lauder promotion turned off');
    }

}

sub _items {
    my ($channel_id) = @_;

    my (undef,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        channel_id => $channel_id,
    });

    return [ {
        sku => $pids->[0]{sku},
        description => "Suede thigh-high boots",
        unit_price => 691.30,
        tax => 48.39,
        duty => 0.00
    } ];
}
