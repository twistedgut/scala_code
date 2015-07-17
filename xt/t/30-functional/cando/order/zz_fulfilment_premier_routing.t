#!/usr/bin/env perl
# DISCLAIMER: This test was written by Mark Knoop
# when he was very new. It clearly should not be a
# mech test and duplicates much tested elsewhere
# however I needed some kind of test to cover the
# code change to EN-238

use NAP::policy qw( test );

use Test::XTracker::Data;
# at the time of writing the times are hardcoded for uk and only used by NAP
# hence skip tests if we can't get CHANNEL__NAP_INTL
# and only run test on that channel if we can
use Test::XTracker::RunCondition(
    dc        => 'DC1',
    prl_phase => 0,
    export    => qw( $iws_rollout_phase ),
);

use Test::XTracker::Data::CMS;
use Test::XT::Flow;
use XTracker::Config::Local qw( config_var dc_address );
use XTracker::Constants::FromDB qw/
    :channel
    :shipment_type
    :shipment_status
    :shipment_item_status
    :shipment_status
    :shipment_class
    :shipment_type
    :shipping_charge_class
    :authorisation_level
    :correspondence_templates
/;
use XTracker::Database qw( get_database_handle );
use XTracker::Database::Routing qw( get_routing_export_list );

use Test::XTracker::PrintDocs;

use Data::Dumper;

my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__OPERATOR => [
        'Customer Care/Order Search',
        'Fulfilment/Packing',
        'Fulfilment/Premier Routing',
        'Fulfilment/Packing Exception',
        'Fulfilment/Picking',
        'Fulfilment/Selection'
    ]}
});

my $schema = $framework->schema;
my $print_directory = Test::XTracker::PrintDocs->new();

# make sure the 'Dispatch Order' Email Template has CMS ID
Test::XTracker::Data::CMS->set_ifnull_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER );

# mixture of mech and framework->mech solely because
# the original script used $mech everywhere, and I've
# only added $framework->mech for those cases where
# the basic mech class doesn't include what we need

my $mech = $framework->mech;

# FIXME: NAP ONLY TEST
my $channel = $schema->resultset('Public::Channel')->find($CHANNEL__NAP_INTL);

# The below pre-run of the routing export is to clear any left overs
$framework->flow_mech__fulfilment__premier_routing
    ->flow_mech__fulfilment__premier_routing__export_manifest({
        channel_id => $channel->id
    });

my $dc_name = config_var('DistributionCentre','name');

note "$dc_name Creating Order for Channel: ".$channel->name." (".$channel->id.")";

my $default_carrier = config_var('DistributionCentre','default_carrier');

my $ship_account    = Test::XTracker::Data->find_shipping_account( { channel_id => $channel->id, carrier => $default_carrier."%" } );
my $prem_postcode   = Test::XTracker::Data->find_prem_postcode( $channel->id );
my $postcode        = ( defined $prem_postcode ? $prem_postcode->postcode : 'NW10 4GR');

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

my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

my $pids = undef;
($channel,$pids) = Test::XTracker::Data->grab_products({ how_many => 2 });

# for each pid make sure there's stock
foreach my $item (@{$pids}) {
    Test::XTracker::Data->ensure_variants_stock($item->{pid});
}

# the order that will whistle through
my ($good_order, $good_order_hash) = Test::XTracker::Data->create_db_order({
    base => {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__PREMIER,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
        shipping_charge_id => 4,
        premier_routing_id => 2,
    },
    pids => [ $pids->[0] ],
    attrs => [
        { price => 100.00 },
    ],
});

# the order that will get b0rked at packing
my ($px_order, $px_order_hash) = Test::XTracker::Data->create_db_order({
    base => {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__PREMIER,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
        shipping_charge_id => 4,
        premier_routing_id => 2,
    },
    pids => [ $pids->[1] ],
    attrs => [
        { price => 200.00 },
    ],
});


my ($good_order_nr,$px_order_nr) = ($good_order->order_nr,$px_order->order_nr);

note "Shipping Acc.: ".$ship_account->id;
note "Cust Nr/Id : ".$customer->is_customer_number."/".$customer->id;

note "Order numbers: Good=$good_order_nr, PX=$px_order_nr";
note "Order IDs: Good=".$good_order->id.", PX=".$px_order->id;

my ($px_ship_nr, $px_status, $px_category) = gather_order_info($px_order_nr);
note "PX shipment Nr: $px_ship_nr";

# Set the source_app_name order_attribute
my $o_attr = $schema->resultset('Public::OrderAttribute')->find_or_create( {
    orders_id => $good_order->id
} );
$o_attr->update( { source_app_name => 'XTracker Test' } );

# Drive PX shipment through to packing, then make it an exception

my $px_skus= $mech->get_order_skus();

$mech->test_direct_select_shipment( $px_ship_nr );

$px_skus = $mech->get_info_from_picklist($print_directory, $px_skus);

$mech->test_pick_shipment( $px_ship_nr, $px_skus );

# now put it into packing exception

$framework->errors_are_fatal(0);
$framework
    ->flow_mech__fulfilment__packing
    ->flow_mech__fulfilment__packing_submit( $px_ship_nr )
    ->flow_mech__fulfilment__packing_checkshipment_submit(
        fail => {
            (keys %{$px_skus})[0] => 'on fire',
        }
    );
is($framework->mech->uri->path,
   '/Fulfilment/Packing/PlaceInPEtote',
   'pack QC fail requires putting items into another tote');
like($framework->mech->app_error_message,
     qr{send to the packing exception desk},
     'packer asked to send shipment to exception desk');
$framework->errors_are_fatal(1);

# Make sure this shipment goes through the "right" workflow rather than having a test
# that deliberately shortcuts the whole process going from failed QC to packing exception
my ($pe_container) = Test::XT::Data::Container->get_unique_ids( { how_many => 1 });
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( (keys %{$px_skus})[0] );
    $framework->flow_mech__fulfilment__packing_placeinpetote_scan_item( $pe_container );

my ($good_ship_nr, $good_status, $good_category) = gather_order_info($good_order_nr);
note "Good shipment Nr: $good_ship_nr";

# Drive good shipment through to packing, and actually pack it
my $good_skus= $mech->get_order_skus();

# PEC WARN, this is damn slow... :(
$mech->test_direct_select_shipment( $good_ship_nr );

$good_skus = $mech->get_info_from_picklist($print_directory, $good_skus);
$mech->test_pick_shipment( $good_ship_nr, $good_skus )
     ->test_pack_shipment( $good_ship_nr, $good_skus );

# Now premier documents ar printed at packing
# completed for all DCs
if ( config_var('Print_Document', 'requires_premier_packing_printouts') ) {
    my @print_docs = $print_directory->wait_for_new_files(
        files => 2
    ); # should always be _something_ outputted
    test_premier_paperwork_printing(@print_docs);
}

########################

# now we should have both orders in the right state to test premier routing

$framework->flow_mech__fulfilment__premier_routing
    ->flow_mech__fulfilment__premier_routing__export_manifest({
        channel_id => $channel->id
    });

### FIX EN-238 Needed to ensure we get the correct
# routing file - get routing export id
# via shipment id and use that?
my $dbh = $schema->storage->dbh;

my $routing_export_ref = get_routing_export_list ( $dbh, { 'type' => 'shipment', 'shipment_id' => $good_ship_nr } );

note "Good shipment routing: ".Dumper $routing_export_ref;

my $routing_export_id;

foreach my $dt_id (sort keys %$routing_export_ref) {
    $routing_export_id = $routing_export_ref->{$dt_id}->{id};
}

note "Routing export id: $routing_export_id";

$framework->flow_mech__fulfilment__premier_routing__click_on_export_number( $routing_export_id );
$mech->follow_link_ok(
    { url_regex => qr/routing.*\.txt/ },
    "Getting text file"
);

# make sure we try to read two rows, to make sure that
# the PX item hasn't been included in the export anyway
my ($line1,$line2) = split /\n/, $mech->content();

note "Line1: ".$line1;
note "Line2: ".$line2 if $line2;

my @fields = split /\|/, $line1;

is (@fields, 22, "There are 22 fields");
is ($fields[1], $good_ship_nr, "Second field is the correct Good shipment number");
is ($fields[12], "", "Email address is not printed");
is ($fields[15], "16:00", "Sixteenth field is 16:00");

is($line2,'',"Packing Exception order $px_order_nr NOT included in export file");

# now, Dispatch the Shipment by clicking on 'Complete Export'
$framework->flow_mech__fulfilment__premier_routing
            ->flow_mech__fulfilment__premier_routing__click_on_export_number( $routing_export_id )
                ->flow_mech__fulfilment__premier_routing__complete_export;
_check_shipment_is_dispatched( $good_order->discard_changes->get_standard_class_shipment );


# now, fix the packing exception shipment
$framework
    ->flow_mech__fulfilment__packingexception
    ->flow_mech__fulfilment__packingexception_submit( $px_ship_nr )
    ->flow_mech__fulfilment__packing_checkshipmentexception_ok_sku( (keys %{$px_skus})[0] )
    ->flow_mech__fulfilment__packing_checkshipmentexception_submit;

# Get shipment to packing stage
$mech->test_pack_shipment( $px_ship_nr, $px_skus );

# Now premier documents ar printed at packing
# completed for all DCs
if ( config_var('Print_Document', 'requires_premier_packing_printouts') ) {
    my @print_docs = $print_directory->wait_for_new_files(
        files => 2
    ); # should always be _something_ outputted
    test_premier_paperwork_printing(@print_docs);
}

########################

# now we should have an order in the right state

$framework->flow_mech__fulfilment__premier_routing
    ->flow_mech__fulfilment__premier_routing__export_manifest({
        channel_id => $channel->id
    });

$routing_export_ref = get_routing_export_list ( $dbh, { 'type' => 'shipment', 'shipment_id' => $px_ship_nr } );

note "PX shipment routing: ".Dumper $routing_export_ref;

foreach my $dt_id (sort keys %$routing_export_ref) {
    $routing_export_id = $routing_export_ref->{$dt_id}->{id};
}

note "Routing export id: $routing_export_id";

$framework->flow_mech__fulfilment__premier_routing__click_on_export_number( $routing_export_id );
$mech->follow_link_ok(
    { url_regex => qr/routing.*\.txt/ },
    "Getting text file"
);

# finally we have the routing file

($line1) = split /\n/, $mech->content();

note "Line1: ".$line1;

@fields = split /\|/, $line1;

is (@fields, 22, "There are 22 fields");
is ($fields[1], $px_ship_nr, "Second field is the correct PX shipment number");
is ($fields[12], "", "Email address is not printed");
is ($fields[15], "16:00", "Sixteenth field is 16:00");

# now, Dispatch the Shipment by clicking on 'Complete Export'
$framework->flow_mech__fulfilment__premier_routing
            ->flow_mech__fulfilment__premier_routing__click_on_export_number( $routing_export_id )
                ->flow_mech__fulfilment__premier_routing__complete_export;
_check_shipment_is_dispatched( $px_order->discard_changes->get_standard_class_shipment );


# restore CMS Id on Email Template
Test::XTracker::Data::CMS->restore_cms_id_for_template( $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER );


done_testing;

sub gather_order_info {
   my ($order_nr) = @_;

   $mech->order_nr($order_nr);

   $mech->get_ok($mech->order_view_url);

   # On the order view page we need to find the shipment ID

   my $ship_nr = $mech->get_table_value('Shipment Number:');

   my $status = $mech->get_table_value('Order Status:');

   my $category = $mech->get_table_value('Customer Category:');

  return ($ship_nr, $status, $category);
}

=head2 test_premier_paperwork_printing

This test is only for DC1, so at packing for premier
the only documents that are printed are the customer invoice
and the returns proforma. Only for JC, in case that the address
card wan't printed at picking, it will be printed at packing

=cut

sub test_premier_paperwork_printing {
    my @print_docs = @_;

    my @printed_file_types = sort map { $_->file_type } @print_docs;
    my @expected_file_types = qw/invoice retpro/;
    is(@printed_file_types,@expected_file_types,"Found premier paperwork printing");
}

sub _check_shipment_is_dispatched {
    my ( $shipment )    = @_;

    my $ship_id = $shipment->id;

    my @ship_items  = $shipment->shipment_items->all;
    cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DISPATCHED, "Shipment (Id: ${ship_id}) is now 'Dispatched'" );
    foreach my $ship_item ( @ship_items ) {
        cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__DISPATCHED,
                                "Shipment Item is 'Dispatched'" );
    }

    # no 'Dispatch Order' emails should have been sent
    cmp_ok(
            $shipment->shipment_email_logs->search( { correspondence_templates_id => $CORRESPONDENCE_TEMPLATES__DISPATCH_ORDER } )
                                            ->count(),
            '==',
            0,
            "No 'Dispatch Order' Emails have been Sent"
        );

    return;
}
