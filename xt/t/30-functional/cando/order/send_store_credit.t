#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :currency
                                        :shipment_status
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                        :authorisation_level
                                        :renumeration_type
                                        :renumeration_class
                                        :renumeration_status
                                    );

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::MessageQueue;

use XTracker::Config::Local         qw( config_var dc_address );
use XTracker::Database::Shipment    qw( get_postcode_shipping_charges get_state_shipping_charges get_country_shipping_charges
                                        :carrier_automation );

my $mech    = Test::XTracker::Mechanize->new;
my $schema  = Test::XTracker::Data->get_schema;
my $channel = Test::XTracker::Data->get_local_channel();
my $operator= $schema->resultset('Public::Operator')->search( { username => 'it.god' } )->first;
my $amq     = Test::XTracker::MessageQueue->new;

Test::XTracker::Data->set_department('it.god', 'Finance');

__PACKAGE__->setup_user_perms;

$mech->do_login;

note "Creating Order for Channel: ".$channel->name." (".$channel->id.")";

# now DHL is DC2's default carrier for international deliveries need to explicitly set
# the carrier to 'UPS' for this DC2CA test
my $default_carrier = ( $channel->is_on_dc( 'DC2' ) ? 'UPS' : config_var('DistributionCentre','default_carrier') );

my $ship_account    = Test::XTracker::Data->find_shipping_account( { channel_id => $channel->id, carrier => $default_carrier."%" } );
my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode :
                        ( $channel->is_on_dc( 'DC2' ) ? '11371' : 'NW10 4GR' ) );

my $dc_address = dc_address($channel);

my $address         = Test::XTracker::Data->order_address( {
                address         => 'create',
                address_line_1  => $dc_address->{addr1},
                address_line_2  => $dc_address->{addr2},
                address_line_3  => $dc_address->{addr3},
                towncity        => $dc_address->{city},
                county          => '',
                country         => $dc_address->{country},
                postcode        => $postcode,
        } );

my (undef,$pids) = Test::XTracker::Data->grab_products( { channel => $channel, how_many => 2 } );
my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

my $order_args  = {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        items => {
            $pids->[0]{sku} => { price => 100.00 },
            $pids->[1]{sku} => { price => 150.00 },
        },
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
        shipping_charge_id => 4,
    };

my $order   = Test::XTracker::Data->create_db_order( $order_args );

my $order_nr = $order->order_nr;

if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
    diag "Shipping Acc.: ".$ship_account->id;
    diag "Order Nr: $order_nr";
    diag "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;
}

$mech->order_nr($order_nr);

my ($ship_nr, $status, $category) = gather_order_info();
diag "Shipment Nr: $ship_nr" if $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE};

# The order status might be Credit Hold. Check and fix if needed
if ($status eq "Credit Hold") {
    Test::XTracker::Data->set_department('it.god', 'Finance');
    $mech->reload;
    $mech->follow_link_ok({ text_regex => qr/Accept Order/ }, "Order approved");
    ($ship_nr, $status, $category) = gather_order_info();
}
is($status, $mech->get_table_value('Order Status:'), "Order is accepted");

# create a renumeration in the correct status to be shown
# in Finance -> ActiveInvoices
my $shipment    = $order->shipments->first;
my $renum   = $shipment->create_related( 'renumerations', {
                        invoice_nr => '',
                        renumeration_type_id => $RENUMERATION_TYPE__STORE_CREDIT,
                        renumeration_class_id => $RENUMERATION_CLASS__RETURN,
                        renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION,
                        currency_id => $CURRENCY__GBP,
                        misc_refund => 50,
                    } );
# and add a log
$renum->create_related( 'renumeration_status_logs', {
                        renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
                        operator_id             => $operator->id,
                    } );
note "Invoice Id: ".$renum->id;

# set-up AMQ Queue name and clear down the queue
my $queue_name  = '/queue/refund-integration-'.$order->channel->web_queue_name_part;
$amq->clear_destination( $queue_name );

# go to the 'Active Invoices' page and process
# the Store Credit Refund
$mech->get_ok( '/Finance/ActiveInvoices' );
ok $mech->find_xpath("//td/a[.='$order_nr']"), 'Order Number found in list';
$mech->submit_form_ok( {
        with_fields => {
            'refund_and_complete-'.$renum->id   => 1,
        },
        button => 'submit'
    }, "Process the Store Credit" );
$mech->no_feedback_error_ok;
$renum->discard_changes;
cmp_ok( $renum->renumeration_status_id, '==', $RENUMERATION_STATUS__COMPLETED, "Renumeration Status set to 'Completed'" );

# Check the AMQ Queue
$amq->assert_messages( {
    destination => $queue_name,
    assert_header => superhashof({
        type => 'RefundRequestMessage',
    }),
    assert_body => superhashof({
        '@type' => 'CustomerCreditRefundRequestDTO',
        orderId => $order->order_nr,
        customerId => $order->customer->is_customer_number,
        createdBy => 'xt-'.$operator->id,
        refundCurrency => $renum->currency->currency,
        refundValues => bag(superhashof({
            '@type' => 'CustomerCreditRefundValueRequestDTO',
            refundValue => 50,
        })),
    }),
}, 'Message sent to Web-Site' );
# clean up after
$amq->clear_destination( $queue_name );


done_testing;


#------------------------------------------------------------------------------------------------

sub setup_user_perms {
  Test::XTracker::Data->grant_permissions( 'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
  Test::XTracker::Data->grant_permissions( 'it.god', 'Finance', 'Active Invoices', $AUTHORISATION_LEVEL__OPERATOR );
}

# First time check that we can get the order via search
# Other times go straight to that url
sub gather_order_info {
  my ($order_nr) = @_;

  $mech->get_ok($mech->order_view_url);

  # On the order view page we need to find the shipment ID

  my $ship_nr = $mech->get_table_value('Shipment Number:');

  my $status = $mech->get_table_value('Order Status:');


  my $category = $mech->get_table_value('Customer Category:');
  return ($ship_nr, $status, $category);
}
