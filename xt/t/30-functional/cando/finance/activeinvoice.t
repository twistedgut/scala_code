#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

activeinvoice.t - Partially tests active invoice page

=head1 DESCRIPTION

=head2 CANDO-65 and CANDO-949

Tests Active Invoice Page - verifies process of allocating remunerations
to invoice - only in sections "Returns - Debits" and "Returns - Card Refunds"

=head2 CANDO-949

    1) Test Active invoice page list PreOrder refunds
    2) Checks Edit invoice (refund) page for preorder has all the data
    3) Checks Cancelling and  Completing refunds functionality (on Edit invoice page)

#TAGS invoice preorder needswork cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::PreOrder;
use Test::XT::Flow;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw(
    :stock_order_status
    :authorisation_level
    :currency
    :renumeration_type
    :renumeration_class
    :renumeration_status
    :pre_order_status
    :pre_order_refund_status

);
use Data::Dumper;
my $schema  = Test::XTracker::Data->get_schema;

my $framework  = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Data::Channel',
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Flow::Finance',
                'Test::XT::Flow::CustomerCare',
                'Test::XT::Flow::Reservations',

            ],
        );

my $channel  = $framework->channel( Test::XTracker::Data->channel_for_nap );
my $operator = $schema->resultset('Public::Operator')->search( { username => 'it.god' } )->first;
my $mech    = $framework->mech;

#--------- Tests ----------------------------
_test_active_invoice_page( $schema, 1 );
_test_active_invoice_page_for_preorder( $schema, 1 );
#--------------------------------------------
done_testing;
#-----------------------------------------------------------------


sub _test_active_invoice_page {
    my( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_test_active_invoice_page", 1 if( !$oktodo);

        note "TESTING Active Invoice Page";

        $framework->mech->channel( $channel );
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $framework->login_with_permissions( {
                    perms   => {
                        $AUTHORISATION_LEVEL__OPERATOR => [
                            'Finance/Active Invoices',
                            'Customer Care/Customer Search',
                        ],
                    },
            } );


        # === Create Order ===========
        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                        channel => $framework->channel,
                                        products => 1,
                                    );
        my $order       = $orddetails->{order_object};
        my $shipment    = $orddetails->{shipment_object};
        my $prn_log_rs  = $shipment->shipment_print_logs->search( {}, { order_by => 'id DESC' } );
        my $last_id     = $prn_log_rs->first ? $prn_log_rs->first->id : 0;

        ok($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr.', shipment id: '.$shipment->id );

        # === Create renumeration having Card Debit =========

        my $renumeration = $shipment->create_related( 'renumerations', {
                        invoice_nr => '',
                        renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                        renumeration_class_id => $RENUMERATION_CLASS__RETURN,
                        renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION,
                        currency_id => $CURRENCY__GBP,
                        misc_refund => 50,
                    } );


        # and add a log
        $renumeration->create_related( 'renumeration_status_logs', {
                        renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
                        operator_id             => $operator->id,
                    } );


        note "Invoice Id: ".$renumeration->id;

        # got to Finance/ActiveInvoices page
        $framework->flow_mech__finance__activeinvoices;

        #channel tab
        my $page  = $framework->mech->as_data()->{'invoice_headers'}{ uc( $channel->name ) };


        # 1) check if the order appears in active invoice list
        my $results = $page->{"Returns - Debits"}; # Returns - Debits should have the order listed
        my @row   = grep { $_->{'Order Number'}->{value} == $order->order_nr} @{ $results };
        ok( @row, "Debit : Order is listed in Active Invoice Page" );

        # 2) check if the headers list Reset PSP heading
        ok(!exists $row[0]->{'Reset PSP'}, "Debit: Reset PSP checkbox does not exist");

        # 3) got to edit invoice page and check things (Finance/ActiveInvoices/Invoice)
        $framework->flow_mech__finance__edit_invoice( $order->id, $shipment->id, $renumeration->id );
        my $page_data = $framework->mech->as_data();

        my $status =  $page_data->{invoice_details}->{Status}->{select_selected}[1];
        $status =~ s/^\s+//; #remove leading spaces
        $status =~ s/\s+$//;
        #  4a) check dropdown has Awaiting Actions selected
        cmp_ok( $status, "eq", 'Awaiting Action', "Debit: Awaiting action is selected" );

        # submit form to have Manual status
        $framework->flow_mech__finance___refundForm_submit( 'status_id' , $RENUMERATION_STATUS__PRINTED);
        $page_data = $framework->mech->as_data();

        $status = $page_data->{invoice_details}->{Status};
        $status =~ s/^\s+//; #remove leading spaces
        $status =~ s/\s+$//;

        # 4b) check view page has Manual displayed
        cmp_ok( $status, "eq", 'Manual', "Status Manual  is selected" );

        # 4c) check if Invoice Status Log has Manual displayed
        # check Logs messages as well
        $results = $page_data->{invoice_status_log};
        my $row = grep { $_->{Status} eq 'Manual'} @{ $results};
        ok($row, "Manual is in the log status");


        # 5) check order view page for status = Manual
        $framework->flow_mech__customercare__orderview($order->id);
        $page_data = $framework->mech->as_data()->{meta_data};
        $results = $page_data->{payments_and_refunds};
        @row   = grep { $_->{'Status'} eq 'Manual'} @{ $results };
        ok( @row, "Manual is listed in Order view page" );

        # ==== Create another card Debit to check checkbox Manual on Active inovice page
        $renumeration = $shipment->create_related( 'renumerations', {
                        invoice_nr => '',
                        renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                        renumeration_class_id => $RENUMERATION_CLASS__RETURN,
                        renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION,
                        currency_id => $CURRENCY__GBP,
                        misc_refund => 50,
                    } );


        # and add a log
        $renumeration->create_related( 'renumeration_status_logs', {
                        renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
                        operator_id             => $operator->id,
                    } );


        note "Invoice Id: ".$renumeration->id;

        # got to Finance/ActiveInvoices page
        $framework->flow_mech__finance__activeinvoices;

        #channel tab
        $page  = $framework->mech->as_data()->{'invoice_headers'}{ uc( $channel->name ) };


        # 1) check if the order appears in active invoice list
        $results = $page->{"Returns - Debits"}; # Returns - Debits should have the order listed
        @row   = grep { $_->{'Order Number'}->{value} == $order->order_nr} @{ $results };
        ok( @row, "Debit : Order is listed in Active Invoice Page" );

        # 2) Click on manual checkbox and submit
        $framework->flow_mech__finance___activeInvoice_submit( 'print', $renumeration->id , $channel->business->config_section);

        # 3) Check the request does not go to printer
        $prn_log_rs->reset;
        my $new_id   = $prn_log_rs->first ? $prn_log_rs->first->id : 0;
        cmp_ok( $new_id, "eq", $last_id, "There is NO new Shipment Print Log record created");

        # 4) Go to edit invoice page and check things (Finance/ActiveInvoices/Invoice)
        $framework->flow_mech__finance__edit_invoice( $order->id, $shipment->id, $renumeration->id );
        $page_data = $framework->mech->as_data();

        $status =  $page_data->{invoice_details}->{Status}->{select_selected}[1];
        $status =~ s/^\s+//; #remove leading spaces
        $status =~ s/\s+$//;
        # 4a) check view page has Manual displayed
        cmp_ok( $status, "eq", 'Manual', "Status Manual  is selected" );

        # 4b) check if Invoice Status Log has Manual displayed
        # check Logs messages as well
        $results = $page_data->{invoice_status_log};
        $row = grep { $_->{Status} eq 'Manual'} @{ $results};
        ok($row, "Manual is in the log status");


        # === Create renumeration having Card Credit =========
        $renumeration = $shipment->create_related( 'renumerations', {
                        invoice_nr => '',
                        renumeration_type_id => $RENUMERATION_TYPE__CARD_REFUND,
                        renumeration_class_id => $RENUMERATION_CLASS__RETURN,
                        renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION,
                        currency_id => $CURRENCY__GBP,
                        misc_refund => 50,
                    } );

        # and add a log
        $renumeration->create_related( 'renumeration_status_logs', {
                        renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
                        operator_id             => $operator->id,
                    } );


        note "Invoice Id: ".$renumeration->id;

        $framework->flow_mech__finance__activeinvoices;
        $page  = $framework->mech->as_data()->{'invoice_headers'}{ uc( $channel->name ) };


         # 1) check if the order appears in active invoice list
         $results = $page->{"Returns - Card Refunds"};
         @row   = grep { $_->{'Order Number'}->{value} == $order->order_nr} @{ $results };
        ok( @row, "Credit: Order is listed in Active Invoice Page" );

        # 2) check if the headers have Reset PSP heading
        ok(exists $row[0]->{'Reset PSP'}, "Credit: Reset PSP checkbox appears for Credits");

        # 3) Click on manual checkbox and submit
        $framework->flow_mech__finance___activeInvoice_submit( 'print', $renumeration->id ,$channel->business->config_section);

        #check the request goes to printer
        $prn_log_rs->reset;
        $new_id   = $prn_log_rs->first ? $prn_log_rs->first->id : 0;
        cmp_ok( $new_id, '>', $last_id, "Credit: There is new Shipment Print Log record created" );

        #4) got to edit invoice page and check things
        $framework->flow_mech__finance__edit_invoice( $order->id, $shipment->id, $renumeration->id);
        $page_data = $framework->mech->as_data();


        $status =  $page_data->{invoice_details}->{Status}->{select_selected}[1];
        $status =~ s/^\s+//; #remove leading spaces
        $status =~ s/\s+$//;
        #  4a) check dropdown has manual selected
        cmp_ok( $status, "eq", 'Manual', "Manual is selected" );

        # 4b)check Logs messages as well
        $results = $page_data->{invoice_status_log};
        $row = grep { $_->{Status} eq 'Manual'} @{ $results};
        ok($row, "Manual is in the log status");

        # 5) check order view page for status = Manual
        $framework->flow_mech__customercare__orderview($order->id);
        $page_data = $framework->mech->as_data()->{meta_data};
        $results = $page_data->{payments_and_refunds};
        @row   = grep { $_->{'Status'} eq 'Manual'} @{ $results };
        ok( @row, "Manual is listed in Order view page" );

    };
}

sub _test_active_invoice_page_for_preorder {
    my( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_t_active_invoice_page_for_preorder", 1 if( !$oktodo);

        note "TESTING Active Invoice Page For PreOrder Data";

        $framework->mech->channel( $channel );
        Test::XTracker::Data->set_department('it.god', 'Finance');
        $framework->login_with_permissions( {
                    perms   => {
                        $AUTHORISATION_LEVEL__OPERATOR => [
                            'Finance/Active Invoices',
                            'Stock Control/Reservation',
                            'Customer Care/Customer Search',
                        ],
                    },
            } );


        # Create PreOrder
        my $pre_order   = Test::XTracker::Data::PreOrder->create_complete_pre_order;
        my $channel     = $pre_order->customer->channel;

        my $stock_manager   = _stock_manager( $channel );

        # generate a Refund for the Pre-Order
        my $refund = $pre_order->cancel( { stock_manager => $stock_manager, cancel_pre_order => 1 } );
        $refund->update( { sent_to_psp => 1 } );
        my $refund_id = $refund->id;


        # got to Finance/ActiveInvoices page
        $framework->flow_mech__finance__activeinvoices;

        # 1) check if the pre-order appears in active invoice list
        my @row   = _get_pre_order_row( $framework, $channel, $pre_order->pre_order_number );
        ok( @row, "Pre-Order is listed in Active Invoice Page" );

        # 2) check if the headers list Reset PSP heading
        ok(exists $row[0]->{'Reset PSP'}, "Reset PSP checkbox exist");
        like( $row[0]->{'Reset PSP'}->{input_name}, qr/reset_sent_to_psp_preorder-$refund_id/,
                                        "and has a checkbox to click on" );


        # 2a) check if the headers does NOT list Manual heading
        ok(!exists $row[0]->{'Manual'}, "Manual Heading does not exist");

        # 2c) check Complete Heading
        ok(exists $row[0]->{'Complete'}, "Complete Heading checkbox exist");
        ok(!$row[0]->{'Complete'}, "and is empty");

        # update sent_to_psp flag to true
        $refund->update( {sent_to_psp => 1} );
        cmp_ok($refund->sent_to_psp, '==', 1, "Updated sent_to_psp flag");

        # 3) Click on Reset to PSP and submit
        $framework->flow_mech__finance__activeinvoices
                    ->flow_mech__finance___activeInvoice_submit( 'reset_sent_to_psp_preorder', $refund->id ,$channel->business->config_section);
        $framework->errors_are_fatal(1);
        @row    = _get_pre_order_row( $framework, $channel, $pre_order->pre_order_number );

        $refund->discard_changes;
        cmp_ok($refund->sent_to_psp, '==', 0, "reset_to_psp checkbox works");
        ok(!$row[0]->{'Reset PSP'}, "Reset PSP is empty");

        # check Complete Heading again
        like( $row[0]->{'Complete'}->{input_name}, qr/refund_and_complete_preorder-$refund_id/,
                                        "Complete now has a checkbox to click on" );


        # 3) got to edit invoice page and check things (Finance/ActiveInvoices/PreOrderInvoice)
        $framework->flow_mech__finance__edit_preorder_invoice( $pre_order->id, $refund->id );
        my $page_data = $framework->mech->as_data();

        my $status =  $page_data->{invoice_details}->{Status}[0];
        #  4a) check Pending status is displayed
        cmp_ok( $status, "eq", 'Pending', "Pending status is displayed correctly");

        # 4b) check reason is cancel
        my $reason = $page_data->{invoice_details}->{Reason}[0];
        cmp_ok( $reason, "eq", 'Cancel', "Reason - Cancel is displayed correctly");

        #4c) type is card refund
        my $type  = $page_data->{invoice_details}->{Type}[0];
        cmp_ok( $type, "eq", 'Card Refund', "Type - card Refund is displayed correctly");

        # 4c) check if Invoice Status Log is displayed
        my $results = $page_data->{invoice_status_log};
        my $row = grep { $_->{Status} eq 'Pending'} @{ $results};
        ok($row, "Pending is in the log status");


        #5) submit the form to be cancelled
        $framework->flow_mech__finance___update_preorder_Invoice_submit( 'status_id' , $PRE_ORDER_REFUND_STATUS__CANCELLED);
        $page_data = $framework->mech->as_data();

        $status = $page_data->{invoice_details}->{Status}[0];
        cmp_ok( $status, "eq", 'Cancelled', "Cancelled status is displayed correctly");


        # reset the status back to Pending
        $refund->update_status( $PRE_ORDER_REFUND_STATUS__PENDING, $operator->id );


        #5) submit the form to be completed
        $framework->flow_mech__finance___update_preorder_Invoice_submit( 'status_id' , $PRE_ORDER_REFUND_STATUS__COMPLETE);
        $page_data = $framework->mech->as_data();

        $status = $page_data->{invoice_details}->{Status}[0];
        cmp_ok( $status, "eq", 'Complete', "Complete status is displayed correctly");

        $framework->flow_mech__finance__activeinvoices;

        my $page    = $framework->mech->as_data()->{'invoice_headers'}{ uc( $channel->name ) };


        # 7) check if the pre-order DOES appears in active invoice list
        $results = $page->{"PreOrder - Card Refunds"};

        my @data   = grep { $_->{'Pre-Order Number'}->{value} eq $pre_order->pre_order_number} @{ $results };
        cmp_ok( scalar(@data), '==', 0,  "Pre-Order is Not listed in Active Invoice Page" );

    };
}

#-----------------------------------------------------------------

# get a Stock Management Object
sub _stock_manager {
    my ($channel )    = @_;
    return XTracker::WebContent::StockManagement->new_stock_manager( { schema => $schema, channel_id => $channel->id } );
}

# return a Pre-Order row from Active Invoices page
sub _get_pre_order_row {
    my ( $framework, $channel, $pre_order_number )  = @_;

    my $page    = $framework->mech->as_data()->{'invoice_headers'}{ uc( $channel->name ) };
    my $results = $page->{"PreOrder - Card Refunds"};
    my @row     = grep { $_->{'Pre-Order Number'}->{value} eq $pre_order_number} @{ $results };

    return @row;
}

1;

