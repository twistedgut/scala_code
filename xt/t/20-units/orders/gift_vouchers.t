#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;

=head2 Tests for Importing Gift Vouchers

This test checks

=over

=item * importing of Orders with Gift Vouchers across All Sales Channels (excluding Jimmy Choo).

=item * orders with gift voucher is put on hold.

=item * order with gift voucher for EIP customers are  NOT put on hold.

=item * orders containing gift vouchers are flaged with "Virtual Voucher" Flag.

=cut


use Test::XTracker::Hacks::TxnGuardRollback;
use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::FraudRule;

use XTracker::Config::Local;
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :order_status
                                        :customer_category
                                        :flag
                                        :shipment_item_returnable_state
                                    );

use Data::Dump  qw( pp );

use Test::XT::Data;

my $ol_id   = $$;

my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );
my $dbh     = $schema->storage->dbh;
my @channels= $schema->resultset('Public::Channel')->enabled;

$schema->txn_begin;

Test::XTracker::Data::FraudRule->switch_all_channels_off();

foreach my $channel ( @channels ) {

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
        ],
    );

    $data->channel( $channel );     # explicitly set the Sales Channel otherwise it will default to NaP
    my $customer= $data->customer;
    $customer->update({ category_id => $CUSTOMER_CATEGORY__NONE});

    my ($forget,$pids)  = Test::XTracker::Data->grab_products( {
                how_many => 1,
                channel => $channel,
                phys_vouchers   => {
                    how_many => 1,
                    want_stock => 10,
                    value => '100.00',
                },
                virt_vouchers   => {
                    value => '50.00',
                    how_many => 1,
                },
        } );

    my $product     = $pids->[0];
    my $pvoucher    = $pids->[1]{product};      # Physical Gift Voucher
    my $vvoucher    = $pids->[2]{product};      # Virtual Gift Voucher

    # Set-up options for the the Order XML file that will be created
    my $order_args  = [
        {
            customer => { id => $customer->is_customer_number },
            order => {
                channel_prefix => $channel->business->config_section,
                tender_amount => 291.50,
                shipping_price => 10,
                shipping_tax => 1.50,
                items => [
                    {
                        sku => $product->{sku},
                        description => $product->{product}
                                                ->product_attribute
                                                    ->name,
                        unit_price => 100,
                        tax => 10,
                        duty => 0,
                    },
                ],
                voucher_items => [
                    {
                        sku => $pvoucher->variant->sku,
                        description => $pvoucher->name,
                        ol_id => ++$ol_id,
                        unit_price => $pvoucher->value,
                        tax => 10,
                        duty => 0,
                        to => 'Recipient',
                        from => 'Sender',
                        message => 'Gift Message',
                    },
                ],
                virtual_deliveries => [
                    {
                        email => 'recipient_email@email.com',
                        voucher_items => [
                            {
                                sku => $vvoucher->variant->sku,
                                description => $vvoucher->name,
                                ol_id => ++$ol_id,
                                unit_price => $vvoucher->value,
                                tax => 10,
                                duty => 0,
                                to => 'Recipient',
                                from => 'Sender',
                                message => 'Gift Message',
                            }
                        ],
                    }
                ],
            },
        },
        {
            customer => { id => $customer->is_customer_number, email => $customer->email },
            order => {
                items   => [
                {
                    sku         => $product->{sku},
                    unit_price  => 250,
                    tax         => 0.00,
                    duty        => 0.00,
                },
            ],
                channel_prefix => $channel->business->config_section,
            },
        },
        {
            customer => { id => $customer->is_customer_number, email => $customer->email },
            no_delivery_contact_details => 1,
            order => {
                channel_prefix => $channel->business->config_section,
                tender_amount => 291.50,
                shipping_price => 10,
                shipping_tax => 1.50,
#               do_not_add_line_items => 1,
                items => [],
                virtual_deliveries => [
                    {
                        email => 'recipient_email@email.com',
                        voucher_items => [
                            {
                                sku => $vvoucher->variant->sku,
                                description => $vvoucher->name,
                                ol_id => ++$ol_id,
                                unit_price => $vvoucher->value,
                                tax => 10,
                                duty => 0,
                                to => 'Recipient',
                                from => 'Sender',
                                message => 'Gift Message',
                            }
                        ],
                    }
                ],
            },
        },
        {
            customer => { id => $customer->is_customer_number, email => $customer->email },
            order => {
                channel_prefix => $channel->business->config_section,
                tender_amount => 291.50,
                shipping_price => 10,
                shipping_tax => 1.50,
                items => [],
                voucher_items => [
                    {
                        sku => $pvoucher->variant->sku,
                        description => $pvoucher->name,
                        ol_id => ++$ol_id,
                        unit_price => $pvoucher->value,
                        tax => 10,
                        duty => 0,
                        to => 'Recipient',
                        from => 'Sender',
                        message => 'Gift Message',
                    },
                ],
                # checks the default RETURNABLE state of 'No' is used for Vouchers
                with_no_returnable_state => 1,
            },
        },

    ];

    # Create and Parse all Order Files
    my $parsed = Test::XTracker::Data::Order->create_order_xml_and_parse($order_args);
    my $data_order = $parsed->[0];

    note " ***** Test that Orders with Gift Vouchers can be Imported";

    # process the order
    my $order   = $data_order->digest();
    isa_ok( $order, "XTracker::Schema::Result::Public::Orders", "Order Digested" );
    cmp_ok( $order->channel_id, '==', $channel->id, "sanity check: Order is for correct Sales Channel: ".$channel->id." - ".$channel->name );

    my $shipment    = $order->get_standard_class_shipment;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'variant_id,voucher_variant_id' } )->all;
    cmp_ok( @ship_items, '==', 3, "Three Shipment Items Created" );

    # check out the items are what is expected

    # Normal Product
    ok( !$ship_items[0]->is_voucher, "First Shipment Item is not a Voucher: ".$ship_items[0]->get_true_variant->sku );
    cmp_ok( $ship_items[0]->variant_id, '==', $product->{variant_id}, "First Shipment Item Variant Id is for expcected Normal Product" );
    cmp_ok( $ship_items[0]->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__YES,
                                "and it's Returnable State is 'Yes'" );

    # Physical Voucher
    ok( $ship_items[1]->is_voucher, "Second Shipment Item is a Voucher: ".$ship_items[1]->get_true_variant->sku );
    ok( $ship_items[1]->is_physical_voucher, "Second Shipment Item is a Physical Voucher" );
    cmp_ok( $ship_items[1]->voucher_variant_id, '==', $pvoucher->variant->id, "Second Shipment Item Variant Id is for expcected Physical Voucher" );
    cmp_ok( $ship_items[1]->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
                                "and it's Returnable State is 'No'" );

    # Virtual Voucher
    ok( $ship_items[2]->is_voucher, "Third Shipment Item is a Voucher: ".$ship_items[2]->get_true_variant->sku );
    ok( $ship_items[2]->is_virtual_voucher, "Third Shipment Item is a Virtual Voucher" );
    cmp_ok( $ship_items[2]->voucher_variant_id, '==', $vvoucher->variant->id, "Third Shipment Item Variant Id is for expcected Virtual Voucher" );
    cmp_ok( $ship_items[2]->returnable_state_id, '==', $SHIPMENT_ITEM_RETURNABLE_STATE__NO,
                                "and it's Returnable State is 'No'" );


    #check order status is credit hold, as it has virtual voucher
    cmp_ok($order->order_status_id, '==', $ORDER_STATUS__CREDIT_HOLD, "Virtual voucher - Order is on Credit Hold");

    #check Virtual Voucher flag is set
    cmp_ok( $order->order_flags->count( { flag_id => $FLAG__VIRTUAL_VOUCHER } ), '==', 1,"For Mixed Order -'Virtual Voucher' Flag is Set" );



    note "****** Test that order with normal products would NOT be put on credit hold";

    $data_order = $parsed->[1];
    # redefine some of the methods so that nothing else would put the order on hold
    no warnings "redefine";
    ## no critic(ProtectPrivateVars)
    *XT::Data::Order::_is_shipping_address_dodgy = \&is_shipping_address_dodgy;
    *XT::Data::Order::_do_hotlist_checks         = \&do_hotlist_checks;
    *XT::Data::Order::_do_customer_order_card_checks= \&do_customer_order_card_checks;
    use warnings "redefine";

    $order = $data_order->digest();

    cmp_ok($order->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "Normal order - Order is on ACCEPTED");

    #check Virtual Voucher flag is not set
    cmp_ok( $order->order_flags->count( { flag_id => $FLAG__VIRTUAL_VOUCHER } ), '==', 0,"For Normal Order - 'Virtual Voucher' Flag is NOT set" );


    note "*********** Test that order with virtual voucher for EIP customer is NOT put on hold";

    # Create an virtual voucher order with customer as an EIP
    $customer->update({ category_id => $CUSTOMER_CATEGORY__EIP_PREMIUM});
    $data_order = $parsed->[2];


    $order = $data_order->digest();
    cmp_ok($order->order_status_id, '==', $ORDER_STATUS__ACCEPTED, "EIP customer with Vvoucher: Order is Accepted");

    #check Virtual Voucher flag is set
    cmp_ok( $order->order_flags->count( { flag_id => $FLAG__VIRTUAL_VOUCHER } ), '==', 1,"Order having only virtual Voucher has 'Virtual Voucher' Flag SET" );


    note " *********** Test order with physical voucher ";
    $data_order = $parsed->[3];


    $order = $data_order->digest();
    #check  Virtual Voucher flag is not set
    cmp_ok( $order->order_flags->count( { flag_id => $FLAG__VIRTUAL_VOUCHER } ), '==', 0,"Physical Voucher -'Virtual Voucher Only' Flag is NOT set");


}

$schema->txn_rollback;


# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

sub is_shipping_address_dodgy {
    return 0;
}


sub do_hotlist_checks {
    return 100;
}


sub do_customer_order_card_checks {

    my ( $self, $order )    = @_;

    # need to re-create this result set so other new code wont fall over
    my $cust_rs = $schema->resultset('Public::Customer')->search( {
            'me.id' => $order->customer_id,
        } );
    $self->_customer_rs( $cust_rs );

    return 100;
}
