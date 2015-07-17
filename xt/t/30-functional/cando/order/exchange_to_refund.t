#!/usr/bin/env perl
use NAP::policy 'test';

# cando-1335 : Exchange to Refund

use Test::XTracker::Data;
use XTracker::Database::Return;
use XTracker::Config::Local         qw( config_var );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :customer_issue_type
                                        :return_item_status
                                        :return_type
                                        :return_status
                                        :renumeration_type
                                        :shipment_item_status
                                        :shipment_status
                                    );
use XT::Domain::Returns;
use Test::XTracker::Mechanize;
use XTracker::Constants     qw( :application );
use XTracker::Stock::Actions::SetReturnBookIn;
use XTracker::EmailFunctions ();

my $global_flag;
REDEFINE: {
    no warnings "redefine";
    *XTracker::Stock::Actions::SetReturnBookIn::get_and_parse_correspondence_template = \&_redefined_method;
;
    use warnings "redefine";
};


my $schema  = Test::XTracker::Data->get_schema();
my $dbh = $schema->storage->dbh;
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );


my %redef_template_args = ();
# get a new instance of 'XT::Domain::Return'
my $domain  = Test::XTracker::Data->returns_domain_using_dump_dir();

#----------------------------------------------------------
_test_exchange_to_refund( $schema, $domain, 1 );
#----------------------------------------------------------

done_testing();

sub _test_exchange_to_refund {
    my ( $schema, $domain, $oktodo )  = @_;

    SKIP: {
        skip "_test_exchange_to_refund", 1        if ( !$oktodo );

        note "in '_test_exchange_to_refund'";

        note "************* Test to check with exchange to refund **************\n";
        #create an exchange with 2 items
        my $no_of_items  = 2;
        my ( $order, $shipment, $items, $pids, $channel )   = _create_an_order($no_of_items);

        my $mech = Test::XTracker::Mechanize->new;
        $mech->do_login;

        Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', 2);
        Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Returns Pending', 2);
        Test::XTracker::Data->set_department('it.god', 'Customer Care');


        $mech->order_nr($order->order_nr);
        my $return;
        # create Exchange and test it created ok
        $mech->test_create_rma( $shipment, 'exchange' )
            ->test_exchange_pending( $return = $shipment->returns->first );

        $return->discard_changes;
        $shipment->discard_changes;
        my $ship_item   = $shipment->shipment_items->order_by_sku->first;
        my $ret_item    = $return->return_items->not_cancelled->first;
        my $exch_item   = $ret_item->exchange_shipment_item;

        note "Shipment Item          ID: ".$ship_item->id.", SKU: ".$ship_item->get_sku;
        note "Return Item            ID: ".$ret_item->id;
        note "Exchange Shipment Item ID: ".$exch_item->id.", SKU: ".$exch_item->get_sku;

        # check shipment/return item statuses
        cmp_ok( $ship_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__RETURN_PENDING, "Shipment Item Status is 'Return Pending'" );
        cmp_ok( $ret_item->return_item_status_id, '==', $RETURN_ITEM_STATUS__AWAITING_RETURN, "Exchnage Return Item Status is 'Awaiting Return'" );
        cmp_ok( $exch_item->shipment_item_status_id, '==', $SHIPMENT_ITEM_STATUS__NEW, "Exchange Shipment Item Status is 'New'" );

        # check that the flag is set
        my $exchange_id = $return->id;
        my $return_obj  = $schema->resultset('Public::Return')->find( $exchange_id );
        my $return_item_info    = XTracker::Database::Return::get_return_item_info($dbh, $exchange_id);
        my $tmp = XTracker::Stock::Actions::SetReturnBookIn::_email_customer($schema,$exchange_id,{},$return_item_info,$APPLICATION_OPERATOR_ID);

        #test flag is not set
        cmp_ok($global_flag, "==", 0 , "'is_exchange_shipment_cancelled' flag is NOT set");
        # check 'payment_info' has been passed to the email template
        ok(
            exists( $redef_template_args{args}{data}{payment_info}{was_paid_using_credit_card} ),
            "'payment_info' was passed to the Email TT Document"
        );

        #convert from exchange
        $mech->test_convert_from_exchange($return);

        $return_obj->discard_changes();
        $return_item_info    = XTracker::Database::Return::get_return_item_info($dbh, $exchange_id);
        $tmp = XTracker::Stock::Actions::SetReturnBookIn::_email_customer($schema,$exchange_id,{},$return_item_info,$APPLICATION_OPERATOR_ID);

        # test flag is set
        cmp_ok($global_flag, "==", 1 ,"'is_exchange_shipment_cancelled' flag is SET");

    };
}

#-------------------------------------------------------------------------------------
# by default this will create a Dispatched Order
sub _create_an_order {
    my ( $num_pids,$channel )  = @_;

    my $schema  = Test::XTracker::Data->get_schema();

    $num_pids   ||= 1;
    $channel    ||= Test::XTracker::Data->channel_for_nap;

    my ( $forget, $pids )  = Test::XTracker::Data->grab_products( {
            how_many    => $num_pids,
            #how_many_variants => 4,
            channel     => $channel,
            ensure_stock_all_variants => 1,
    } );

    my $base    = {
            channel_id => $channel->id,
            shipping_charge => 10,
            tenders => [ { type => 'card_debit', value => 10 + ( 100 * $num_pids ) } ],
        };

    my ( $order, $order_hash )  = Test::XTracker::Data->create_db_order( {
            pids => $pids,
            base => $base,
            attrs => [ map { price => 100, tax => 0, duty => 0 }, ( 1..$num_pids ) ],
        } );

    my $shipment    = $order->get_standard_class_shipment();
    my @ship_items  = $shipment->shipment_items->search( {}, { order_by => 'id' } );

    ok($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr );
    note "Shipment Created: ".$shipment->id;
    return ( $order, $shipment, \@ship_items, $pids, $channel );
}

# use this to Redefine the 'XTracker::EmailFunctions:get_and_parse_correspondence_template' function
sub _redefined_method {
    note "***************** IN REDEFINED 'get_and_parse_correspondence_template' ***********";

    #   $schema, $template_id, $args
    $redef_template_args{schema}= $_[0];
    $redef_template_args{template_id}= $_[1];
    $redef_template_args{args}= $_[2];

    my $data = $redef_template_args{args}->{data};


    #set $global_flag for testing
    $global_flag =  $data->{is_exchange_shipment_cancelled};

    return 1;
}

