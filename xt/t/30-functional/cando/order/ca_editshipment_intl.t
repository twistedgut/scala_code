#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;



use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Config::Local;
use XTracker::Database::Shipment    qw( get_address_shipping_charges );

use XTracker::Constants::FromDB   qw(
                                        :channel
                                        :shipment_item_status
                                        :shipment_status
                                        :shipment_class
                                        :shipment_type
                                        :shipping_charge_class
                                    );
use Test::XTracker::RunCondition dc => 'DC1';
my $schema = Test::XTracker::Data->get_schema;

my $channel_id  = $CHANNEL__NAP_INTL;
my (undef,$pids)= Test::XTracker::Data->grab_products( { channel_id => $channel_id } );
my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel_id } );

Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel_id );


my $mech = Test::XTracker::Mechanize->new;
Test::XTracker::Data->set_department('it.god', 'Customer Care');

__PACKAGE__->setup_user_perms;

$mech->do_login;

# get shipping account id for Domestic DHL
my $shipping_account= Test::XTracker::Data->find_shipping_account({
    channel_id => $channel_id,
    acc_name   => 'Domestic',
    carrier    => 'DHL Express',
});

my $prem_postcode = Test::XTracker::Data->find_prem_postcode( $channel_id );
my $address = Test::XTracker::Data->create_order_address_in("current_dc_premier");

# go get some pids relevant to the db I'm using - channel is for test context
my $channel;
($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 1,
});

my ($order, $order_hash) = Test::XTracker::Data->create_db_order({
    base => {
        customer_id => $customer->id,
        channel_id  => $channel_id,
        shipment_type => $SHIPMENT_TYPE__PREMIER,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $shipping_account->id,
        invoice_address_id => $address->id,
        # get premier shipping charge id
        shipping_charge_id => $prem_postcode->shipping_charge_id,
    },
    pids => $pids,
    attrs => [
        { price => 100.00 },
    ],
});

#===
#my $order = Test::XTracker::Data->create_db_order({
#    customer_id => $customer->id,
#    channel_id  => $channel_id,
#    items => {
#        $pids->[0]{sku} => { price => 100.00 },
#    },
#    shipment_type => $SHIPMENT_TYPE__PREMIER,
#    shipment_status => $SHIPMENT_STATUS__PROCESSING,
#    shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
#    shipping_account_id => $shipping_account->id,
#    invoice_address_id => $address->id,
#    # get premier shipping charge id
#    shipping_charge_id => $prem_postcode->shipping_charge_id,
#});


my $order_nr = $order->order_nr;

if ( $ENV{HARNESS_VERBOSE} || $ENV{HARNESS_IS_VERBOSE} ) {
    diag "Shipping Acc.: $shipping_account";
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

my $skus    = $mech->get_order_skus();

my $edit_shipment   = $mech->test_edit_shipment( $ship_nr );
test_carrier_automation_field( $edit_shipment, $ship_nr );

done_testing;

=head2 test_carrier_automation_field

 test_carrier_automation_field($edit_shipment_page_mech,$shipment_id)

Tests that the carrier automation field can be seen when in DC1

=cut

sub test_carrier_automation_field {
    my ($mech,$ship_nr) = @_;

    my $schema      = Test::XTracker::Data->get_schema;
    my $dbh         = $schema->storage->dbh;

    my $shipment    = $schema->resultset('Public::Shipment')->find( $ship_nr );
    my $address     = $shipment->shipment_address;


    # get shipping options available
    my %shipping_charges = get_address_shipping_charges(
        $dbh,
        $shipment->order->channel_id,
        {
            country  => $address->country,
            postcode => $address->postcode,
            state    => $address->county,
        },
    );

    note "TESTING that carrier automation section appears in DC1";

    # get premier and non-premier shipping charges
    my $premier_charge;
    my @non_prem_charge;
    foreach ( keys %shipping_charges ) {
        if ( $shipping_charges{$_}{class_id} == $SHIPPING_CHARGE_CLASS__SAME_DAY ) {
            $premier_charge = $_;
        }
        else {
            push @non_prem_charge,$_;
        }
    }

    # TEST shouldn't see rtcb field or rtcb section
    $mech->content_like(qr/Shipment Carrier Automation/,'Page Has Carrier Automation Heading');
    is($mech->form_with_fields('rtcb'),undef,'No rtcb field in form');
    cmp_ok($shipment->real_time_carrier_booking,"==",0,"rtcb field is FALSE");

    # TEST shouldn't see rtcb field or rtcb section even if not premier shipment anymore
    $mech->submit_form_ok({
        with_fields => {
                shipping_charge_id  => $non_prem_charge[0]
            },
        button => 'submit'
      }, 'Change Shipping Option to Non-Premier');
    $mech->no_feedback_error_ok;
    $mech->has_feedback_success_ok(qr/Shipment Updated/,"Shipment Updated");

    like($mech->uri->path,qr{/OrderView$},"On Order View Page");
    # PREVENT: Use of uninitialized value $got in numeric eq (==) at (eval in cmp_ok) ca_editshipment_intl.t line 180
    cmp_ok($mech->get_table_row( "Carrier Automated:" )||0,"==",0,"Couldn't Find 'Carrier Automated' field in Shipment Details");
    is($mech->find_image( alt => 'Shipment Automated' ),undef,"Couldn't Find Carrier Automated 'Tick' Either");

    $shipment->discard_changes;

    cmp_ok($shipment->shipment_type_id,"!=",$SHIPMENT_TYPE__PREMIER,'Shipment Type is no longer Premier');
    cmp_ok($shipment->real_time_carrier_booking,"==",0,"rtcb field is still FALSE");

    $mech   = $mech->test_edit_shipment( $ship_nr );
    $mech->content_like(qr/Shipment Carrier Automation/,'Page Still Has Carrier Automation Heading');
    is($mech->form_with_fields('rtcb'),undef,'No rtcb field in form');

    return $mech;
}


sub setup_user_perms {
  Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
  # Perms needed for the order process
  for (qw/Airwaybill Dispatch Packing Picking Selection Labelling/ ) {
    Test::XTracker::Data->grant_permissions('it.god', 'Fulfilment', $_, 2);
  }
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
