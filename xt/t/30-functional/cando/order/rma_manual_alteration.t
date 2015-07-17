#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

use Data::Dump      qw( pp );


use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Test::XTracker::MessageQueue;
use XT::Domain::Returns;

use XTracker::Constants           qw( :application );
use XTracker::Constants::FromDB   qw(
    :authorisation_level
    :currency
    :customer_issue_type
    :shipment_item_status
    :shipment_status
    :shipment_type
    :renumeration_status
    :renumeration_class
    :renumeration_type
    :return_type
    :return_item_status
);

use XTracker::Config::Local             qw( config_var config_section_slurp dc_address );
use XTracker::Database::Invoice         qw( generate_invoice_number );

my $schema  = Test::XTracker::Data->get_schema();

my ( $order, $return )  = _create_an_order( $schema );
my @ret_items           = $return->return_items->search( {}, { order_by => 'id ASC' } )->all;
my $shipment            = $order->get_standard_class_shipment;
my $exch_ship           = $return->exchange_shipment;
my %items;

foreach my $item ( @ret_items ) {
    my $item_type = $item->is_exchange ? 'exchange' : 'return';
    push @{ $items{$item_type}{ret_items} }, $item;
    push @{ $items{$item_type}{ship_items} }, $item->shipment_item;
    push @{ $items{$item_type}{exch_items} }, $item->exchange_shipment_item;
}

# There were the following Returns Generated
#       2 Returns
#       2 Exchanges

##### Start the Mech Testing #####
Test::XTracker::Data->grant_permissions(
    'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );

my $mech    = Test::XTracker::Mechanize->new;
$mech->do_login;
$mech->order_nr( $order->order_nr );

# check can't see 'Manual Alterations Post Refund' link
# when the Return Invoices have not been completed
$mech->get_rma_page( $return );
ok( ( !grep{ defined $_->text && $_->text =~ /Manual Alterations Post Refund/ } $mech->followable_links() ),
                                "'Manual Alterations Post Refund' link is NOT shown when Return Invoices have NOT been 'Completed'" );

# complete the Return Renumerations
my @renums  = $return->renumerations->all;
foreach my $renum ( @renums ) {
    $renum->update_status( $RENUMERATION_STATUS__COMPLETED, $APPLICATION_OPERATOR_ID );
}

# check we can see 'Manual Alterations Post Refund' link
# now that the Return Invoices have been completed
$mech->reload();
ok( ( grep{ defined $_->text && $_->text =~ /Manual Alterations Post Refund/ } $mech->followable_links() ),
                                "'Manual Alterations Post Refund' link IS shown when Return Invoices have been 'Completed'" );

# change some data before checking the page
$items{return}{ret_items}[0]->update( { return_item_status_id => $RETURN_ITEM_STATUS__BOOKED_IN } );

$mech->follow_link_ok( { text_regex => qr/Manual Alterations Post Refund/ } );
ok (
    $mech->look_down (
        _tag => 'p',
        sub {$_[0]->as_trimmed_text =~ /Any updates using this page will.*NOT.*update or adjust any Invoices/}
    ),
    "Bottom of the Table Disclaimer Shown"
);


note "check the rows have the correct checkboxes available";
$mech->form_name("manual_alteration");
my $table  = _get_table( $mech, "data", $return );
foreach my $item ( @ret_items ) {
    my $sku = $item->shipment_item->get_sku;

    ok( exists( $table->{$sku} ), "SKU found in Table Row" );

    if ( $item->is_exchange ) {
        is( $table->{$sku}{Type}, 'Exchange', "Exchanges Type is 'Exchange' in the Table" );
        cmp_ok( $table->{$sku}{cancel_checkbox}, '==', 1, "Exchange Item Has Cancel Checkbox" );
        cmp_ok( $table->{$sku}{convert_checkbox}, '==', 1, "Exchange Item Has Convert Checkbox" );
    }
    else {
        is( $table->{$sku}{Type}, 'Return', "Return's Type is 'Return' in the Table" );
        if ( $item->return_item_status_id == $RETURN_ITEM_STATUS__BOOKED_IN ) {
            cmp_ok( $table->{$sku}{cancel_checkbox}, '==', 0, "'Booked In' Return Doesn't Have Cancel Checkbox" );
        }
        else {
            cmp_ok( $table->{$sku}{cancel_checkbox}, '==', 1, "'Awaiting Return' Return Does Have Cancel Checkbox" );
        }
        cmp_ok( $table->{$sku}{convert_checkbox}, '==', 0, "Return Item Doesn't Have Convert Checkbox" );
    }
}

note "now submit some data and check everything is ok";
$mech->submit_form_ok( {
    form_name   => 'manual_alteration',
    with_fields => {
        "cancel-".$items{return}{ret_items}[1]->id => 1,
        "convert-".$items{exchange}{ret_items}[0]->id => 1,
    },
    button => 'submit',
}, "Submit Form to Cancel & Convert Some Return Items" );
$mech->no_feedback_error_ok;
$mech->has_feedback_success_ok(qr/Updated Item/);
$mech->has_feedback_info_ok(qr{Please Remember:.*No Invoices have been touched},
    "Post Update Disclaimer Shown" );

# check the data
$_->discard_changes for $return, $shipment, $exch_ship;
$_->discard_changes for @{ $items{exchange}{ret_items} }, @{ $items{exchange}{ship_items} }, @{ $items{exchange}{exch_items} };
$_->discard_changes for @{ $items{return}{ret_items} }, @{ $items{return}{ship_items} };
@ret_items  = $return->return_items->search( {}, { order_by => 'id ASC' } )->all;
$mech->form_name("manual_alteration");
$table      = _get_table( $mech, "data", $return );

cmp_ok( $items{return}{ret_items}[1]->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED,
                                            "'Return' Item is now Cancelled" );
cmp_ok( $items{exchange}{ret_items}[0]->return_item_status_id, '==', $RETURN_ITEM_STATUS__CANCELLED,
                                            "Converted 'Exchange' Item is Cancelled" );
cmp_ok( $ret_items[-1]->return_type_id, '==', $RETURN_TYPE__RETURN,
                                            "New Return Item for Converted Exchange is a 'Return'" );
cmp_ok( $ret_items[-1]->shipment_item_id, '==', $items{exchange}{ret_items}[0]->shipment_item_id,
                                            "New Return Item Shipment Item Id is the Same as for the Converted Exchange" );

# check Cancel Items are shown to be Cancelled in the Table
foreach my $item ( $items{return}{ret_items}[1], $items{exchange}{ret_items}[0] ) {
    my $sku = $item->shipment_item->get_sku;
    note "Return Item Id: ".$item->id." - SKU: ".$sku;

    # Cancelled Item should have a Cancelled SKU Key in the Table Ref
    my $key = 'c'.$sku;
    ok( exists( $table->{ $key } ), "Cancelled Item SKU found in Table Row" );

    if ( $item->is_exchange ) {
        like( $table->{ $key }{"Convert From Exchange"}, qr/Exchange Shipment.*Item Status: Cancelled/,
                                            "Cancelled Exchange show Exchange Shipment Item Cancelled Message in Convert column" );
    }

    cmp_ok( $table->{ $key }{cancel_checkbox}, '==', 0, "Cancel Checkbox not Available" );
    cmp_ok( $table->{ $key }{convert_checkbox}, '==', 0, "Convert Checkbox not Available" );
}
# check the newly Created Return is in the table and a Return
my $sku    = $ret_items[-1]->shipment_item->get_sku;
note "New Return Item Id: " . $ret_items[-1]->id . "- SKU: $sku";
ok( exists( $table->{$sku} ), "New Return Item Created for the Converted Exchange is Present in the Table" );
is( $table->{$sku}{Type}, 'Return', "New Return Item's Type is 'Return' in the Table" );
cmp_ok( $table->{$sku}{cancel_checkbox}, '==', 1, "Cancel Checkbox IS Available" );
cmp_ok( $table->{$sku}{convert_checkbox}, '==', 0, "Convert Checkbox is NOT Available" );

note "change some data again and re-load the page to check the state of the checkboxes in the table";
$exch_ship->update( { shipment_status_id => $SHIPMENT_STATUS__PROCESSING } );
$items{exchange}{ret_items}[1]->update( { return_item_status_id => $RETURN_ITEM_STATUS__PASSED_QC } );
$items{exchange}{exch_items}[1]->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__PACKED } );

$mech->reload();
$table  = _get_table( $mech, "data", $return );
$sku    = $items{exchange}{ret_items}[1]->shipment_item->get_sku;
like( $table->{$sku}{"Convert From Exchange"}, qr/Exchange Shipment.*Item Status: Packed/,
                                    "Exchange Item with a Packed Exchange Shipment Item shows 'Packed' message in Convert column" );
cmp_ok( $table->{$sku}{cancel_checkbox}, '==', 0, "Cancel Checkbox not Available for Packed Exchange Item" );
cmp_ok( $table->{$sku}{convert_checkbox}, '==', 0, "Convert Checkbox not Available for Packed Exchange Item" );


done_testing;

################################################################################

# get a table out of a page and put it into a hash with SKU being the key
# and also searches for the checkboxes for the Cancel and Convert columns
sub _get_table {
    my $mech        = shift;
    my $class       = shift;
    my $return      = shift;

    my $hash_ref;
    my $items = $mech->as_data()->{items};

    foreach my $row ( @{ $items } ) {
        my $key = $row->{SKU};
        $key    = 'c'.$key      if ( $row->{Status} eq "Cancelled" );   # set-up a cancelled SKU Key for Cancelled Items

        $row->{convert_checkbox}    = 0;
        $row->{cancel_checkbox}     = 0;

        $hash_ref->{ $key } = $row;
    }

    # get all of the Convert of Cancel action checkboxes
    # and add them to the hash ref built above
    my @inputs  = $mech->find_all_inputs( type => 'checkbox', name_regex => qr/^(convert|cancel)-/ );
    foreach my $input ( @inputs ) {
        if ($input->id =~ m/^(cancel|convert)-(\d*)/) {
            my $action  = $1."_checkbox";
            my $itemid  = $2;

            # now find the SKU for the Return Item Id
            my $retitem = $return->return_items->find( $itemid );
            my $sku     = $retitem->shipment_item->get_sku;
            $hash_ref->{$sku}{ $action }= 1;
        }
    }

    return $hash_ref;
}

# create an order
sub _create_an_order {
    my $schema  = shift;

    my $args    = {};
    my $num_pids= 4;

    my $msg_factory = Test::XTracker::MessageQueue->new({schema=>$schema});
    my $retdomain   = XT::Domain::Returns->new( { msg_factory => $msg_factory, schema => $schema } );

    note "Creating Order";

    my($channel,$pids) = Test::XTracker::Data->grab_products({
        how_many => $num_pids,
    });

    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => config_var('DistributionCentre','default_carrier'), channel_id => $channel->id } );
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
                                                country         => $args->{country} || $dc_address->{country},
                                                postcode        => $postcode,
                                            } );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    my $base = {
        customer_id => $customer->id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => $address->id,
    };


    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => $base,
        attrs => [ map { price => $_ * 100, tax => 0, duty => 0 }, ( 1..$num_pids ) ],
    });

    # clean up data created by the 'create order' test function
    $order->tenders->delete;
    my $shipment    = $order->shipments->first;
    $shipment->renumerations->delete;
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'id ASC' } )->all;

    note "Order Id/Nr: ".$order->id." / ".$order->order_nr;
    note "Shipment Id: ".$shipment->id;

    # create an initial DEBIT invoice
    my $invoice_number = generate_invoice_number( $schema->storage->dbh );
    my $renum   = $shipment->create_related( 'renumerations', {
                                invoice_nr              => $invoice_number,
                                renumeration_type_id    => $RENUMERATION_TYPE__CARD_DEBIT,
                                renumeration_class_id   => $RENUMERATION_CLASS__ORDER,
                                renumeration_status_id  => $RENUMERATION_STATUS__COMPLETED,
                                shipping    => 10,
                                currency_id => ( Test::XTracker::Data->whatami eq 'DC2' ? $CURRENCY__USD : $CURRENCY__GBP ),
                                sent_to_psp => 1,
                                gift_credit => 0,
                                misc_refund => 0,
                                store_credit=> 0,
                                gift_voucher=> 0,
                        } );
    foreach my $item ( @ship_items ) {
        $renum->create_related( 'renumeration_items', {
                                shipment_item_id    => $item->id,
                                unit_price          => $item->unit_price,
                                tax                 => $item->tax,
                                duty                => $item->duty,
                            } );
        note "Shipment Item Id: ".$item->id.", Price: ".$item->unit_price.", Tax: ".$item->tax.", Duty: ".$item->duty;
        $item->update_status( $SHIPMENT_ITEM_STATUS__DISPATCHED, $APPLICATION_OPERATOR_ID );
    }
    $shipment->update_status( $SHIPMENT_STATUS__DISPATCHED, $APPLICATION_OPERATOR_ID );

    $order->create_related( 'tenders', {
                                value   => $renum->grand_total,
                                type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                                rank    => 0,
                            } );

    # create a return
    my $return  = $retdomain->create( {
                        operator_id => $APPLICATION_OPERATOR_ID,
                        shipment_id => $shipment->id,
                        pickup  => 0,
                        refund_type_id  => $RENUMERATION_TYPE__CARD_REFUND,
                        return_items => {
                                $ship_items[0]->id => {
                                    type => 'Exchange',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    exchange_variant => $ship_items[0]->variant_id,
                                },
                                $ship_items[1]->id => {
                                    type => 'Return',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                },
                                $ship_items[2]->id => {
                                    type => 'Exchange',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                    exchange_variant => $ship_items[2]->variant_id,
                                },
                                $ship_items[3]->id => {
                                    type => 'Return',
                                    reason_id => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                },
                            },
                    } );
    note "Created Return: ".$return->id." / ".$return->rma_number;

    $order->discard_changes;
    $return->discard_changes;

    return ( $order, $return );
}
