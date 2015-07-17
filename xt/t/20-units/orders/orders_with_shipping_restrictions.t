#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 Tests for Shipping Restriction Notification

This tests that if an Order has any Products with Shipping Restrictions then Internal Notifications are sent.

=cut

use Test::XTracker::LoadTestConfig;

# redefine 'send_email' for 'XT::Data::Order'
# before anything has time to load it
my @send_email_uses;
no warnings 'redefine';
#*XT::Data::Order::send_email    = \&_redefined_send_email;
*XTracker::Database::Shipment::send_email    = \&_redefined_send_email;
use warnings 'redefine';

use Test::XTracker::Data;

use Test::XTracker::Hacks::TxnGuardRollback;
use Test::XTracker::Data::Order;

use Test::XT::Data;
use Test::XT::Rules::Solve;

use XTracker::Config::Local     qw( config_var );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );
my $dbh     = $schema->storage->dbh;
my @channels= $schema->resultset('Public::Channel')->fulfilment_only(0)->enabled;


foreach my $channel ( @channels ) {

    my $config_section  = $channel->business->config_section;

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
        ],
    );

    $data->channel( $channel );     # explicitly set the Sales Channel otherwise it will default to NaP
    my $customer    = $data->customer;

    my ($forget,$pids)  = Test::XTracker::Data->grab_products( {
                how_many    => 2,
                channel     => $channel,
                ensure_stock=> 1,
        } );

    my $restricted_product  = $pids->[0]{product};
    my $restricted_pid      = $pids->[0]{pid};
    my $restricted_sku      = $pids->[0]{sku};
    my $unrestricted_product= $pids->[1]{product};
    my $unrestricted_sku    = $pids->[1]{sku};

    # put in place the restrictions, the Chinese
    # restriction is common to all DCs
    my $chinese_restriction = Test::XT::Rules::Solve->solve( 'Shipment::restrictions', {
        restriction => 'CHINESE_ORIGIN',
    } );
    $restricted_product->shipping_attribute->update( $chinese_restriction->{shipping_attribute} );
    my $restricted_country  = $schema->resultset('Public::Country')
                                        ->find_by_name( $chinese_restriction->{address}{country} );

    # set-up what's expected in the internal email messages
    my %expected_email_messages = (
        config_var( 'Email_'.$config_section, 'customercare_email' )=> {
            subject => 'Shipment Containing Restricted Products',
            message => re( qr/Restricted Products.*$restricted_pid.*:.*Chinese origin product/si ),
        },
        config_var( 'Email_'.$config_section, 'fulfilment_email' )  => {
            subject => 'Shipment Containing Restricted Products',
            message => re( qr/Restricted Products.*$restricted_pid.*:.*Chinese origin product/si ),
        },
        config_var( 'Email_'.$config_section, 'shipping_email' )    => {
            subject => 'Shipment Containing Restricted Products',
            message => re( qr/Restricted Products.*$restricted_pid.*:.*Chinese origin product/si ),
        },
    );

    # Set-up options for the the Order XML file that will be created
    my $order_args  = [
        {
            customer => {
                id => $customer->is_customer_number,
                country => $restricted_country->code,
            },
            order => {
                channel_prefix => $channel->business->config_section,
                tender_amount => 110.00,
                shipping_price => 10,
                shipping_tax => 1.50,
                items => [
                    {
                        sku => $restricted_sku,
                        description => $restricted_product
                                            ->product_attribute
                                                ->name,
                        unit_price => 100,
                        tax => 10,
                        duty => 0,
                    },
                ],
            },
        },
        {
            customer => { id => $customer->is_customer_number },
            order => {
                channel_prefix => $channel->business->config_section,
                tender_amount => 110.00,
                shipping_price => 10,
                shipping_tax => 1.50,
                items => [
                    {
                        sku => $unrestricted_sku,
                        description => $unrestricted_product
                                            ->product_attribute
                                                ->name,
                        unit_price => 100,
                        tax => 10,
                        duty => 0,
                    },
                ],
            },
        },
    ];

    # Create and Parse all Order Files
    my $parsed = Test::XTracker::Data::Order->create_order_xml_and_parse($order_args);

    # process the Restricted Order
    @send_email_uses= ();
    my $data_order  = $parsed->[0];
    my $order       = $data_order->digest();
    isa_ok( $order, "XTracker::Schema::Result::Public::Orders", "Order Digested" );
    cmp_ok( $order->channel_id, '==', $channel->id, "sanity check: Order is for correct Sales Channel: ".$channel->id." - ".$channel->name );
    my %got = map { $_->{to} => { subject => $_->{subject}, message => $_->{message} } }
                    @send_email_uses;
    cmp_deeply( \%got, \%expected_email_messages, "Got expected Internal Email messages for Order with Restricted Product" );

    # process the Un-Restricted Order
    @send_email_uses= ();
    $data_order = $parsed->[1];
    $order      = $data_order->digest();
    isa_ok( $order, "XTracker::Schema::Result::Public::Orders", "Order Digested" );
    cmp_ok( $order->channel_id, '==', $channel->id, "sanity check: Order is for correct Sales Channel: ".$channel->id." - ".$channel->name );
    cmp_ok( scalar( @send_email_uses ), '==', 0, "No Internal Email messages were sent for Order with NO Restricted Product" );
}



# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

done_testing;

#-------------------------------------------------------------------------------------

sub _redefined_send_email {
    my @params  = @_;

    note "================== IN REDEFINED 'send_email' FUNCTION ==================";

    push @send_email_uses, {
        subject => $params[3],
        message => $params[4],
        to      => $params[2],
    };

    return 1;
}
