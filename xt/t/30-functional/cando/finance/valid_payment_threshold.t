#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

valid_payment_threshold.t - Test Finance / InvalidPayments page

=head1 DESCRIPTION

Verifies that when a shipment item is cancelled the payment does NOT appear
on the invalid payments page.

Separately verifies that when the shipping address is changed the payment on
the associated order IS listed on the page as an invalid payment.

#TAGS orderview xpath cando

=cut

use FindBin::libs;

use Test::XTracker::Data;
use Test::Most;

use base 'Test::Class';

# CANDO-132,1335
use XTracker::Constants::FromDB qw(
    :shipment_status
    :shipment_item_status
    :shipment_type
    :order_status
);
use Test::XT::Flow;
use Test::Role::Address;

sub create_order {
    my ( $self, $args ) = @_;

    my $pids_to_use = $args->{pids_to_use};
    my ($order)     = Test::XTracker::Data->apply_db_order({
        pids => $self->{pids},
        attrs => [ { price => $args->{price} }, ],
        base => {
            tenders  => [
                        { type => 'card_debit', value => 2500 },
                    ],
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_item_status    => $SHIPMENT_ITEM_STATUS__NEW,
        },
    });

    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$order->shipments->first->id;
    # let's make it fail payment
    my $schema  = Test::XTracker::Data->get_schema;
    my $next_preauth    = Test::XTracker::Data->get_next_preauth( $schema->storage->dbh );
    $order->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
    my $payment = Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => $next_preauth,
        preauth_ref => $next_preauth,
    } );
    return $order;
}

sub startup : Tests( startup => 2 ) {
    my $test = shift;
    $test->{schema} = Test::XTracker::Data->get_schema;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 3, channel => 'nap',
    });
    $test->{pids}   = $pids;

    # get one high priority customer class
    my $classes_rs  = $test->{schema}->resultset('Public::CustomerClass')->search;
    while ( my $rec = $classes_rs->next ) {
        if ( $rec->is_finance_high_priority ) {
            $test->{hp_class}   = $rec;
            $test->{hp_cat}     = $rec->customer_categories->first;
            last;
        }
    }

    my $framework = Test::XT::Flow->new_with_traits( {
        traits => [
            'Test::XT::Flow::Finance',
        ],
    } );

    $test->{framework} = $framework;
    $test->{mech}      = $framework->mech;

    $test->{framework}->login_with_roles( {
        paths => [
            '/Finance/InvalidPayments',
        ],
        main_nav => [
            'Customer Care/Order Search',
            'Customer Care/Customer Search',
        ],
    } );
    Test::XTracker::Data->set_department( $test->{mech}->logged_in_as, 'Customer Care' );
}

sub test_invalid_payment_with_cancel_items : Tests {
    my $test        = shift;
    my $mech        = $test->{mech};
    my $schema      = $test->{schema};

    my $found;
    my $framework = Test::XT::Flow->new_with_traits(
    traits => ['Test::XT::Flow::CustomerCare',
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Data::Customer',
                'Test::XT::Data::Channel',
              ],
        mech   => $mech,
    );

     # Create order with shipment with status = Processing
     my $order           = $test->create_order();#$orddetails->{order_object};
     my $shipment        = $order->shipments->first;
     my $customer        = $order->customer;

     $shipment->update({ shipment_status_id => $SHIPMENT_STATUS__PROCESSING });

     #update has_packing_started flag to false
     $shipment->update({ has_packing_started => 'FALSE' });

     note "************ Order id : ". $order->id ." and shipment id: ". $shipment->id;

    $framework->flow_mech__customercare__orderview( $order->id )
    ->flow_mech__customercare__cancel_shipment_item;

    my $pre_change_form = $framework->mech->as_data;

    # just cancel the first item
    my $first_item = $pre_change_form->{cancel_item_form}->{select_items}->[0];

    my $pid = $first_item->{PID};
    note "PID of cancelled item is $pid";

    $framework->flow_mech__customercare__cancel_item_submit( $pid )
        ->flow_mech__customercare__cancel_item_email_submit();

    $order->discard_changes();

    $mech->get_ok( '/Finance/InvalidPayments' );
    $found = $mech->find_xpath('//td[@class="highlight4"]/a[@href="/Finance/InvalidPayments/OrderView?order_id='.$order->id.'"]');

    # since value is less it should not be in the invalid table
    ok(!scalar($found->get_nodelist), "Order: ".$order->id." is NOT in Table " );
    cmp_ok ($order->payments->first->valid, "==", 1 , "Payment Valid flag is set to TRUE");


}

sub test_invalid_payments_with_address_change : Tests {
    my $test = shift;
    my $mech        = $test->{mech};
    my $schema      = $test->{schema};
    my $found;

    # Create an order with failed payment
    my $order       = $test->create_order();

    # Set the pre-auth value to zero, shipping charge to 0
    # and item's unit price to 1 to ensure the address change
    # makes the order go in to the Invalid Payments queue.
    $order->update( { pre_auth_total_value => 0 } );
    my $shipment    = $order->get_standard_class_shipment;
    $shipment->update( { shipping_charge => 0 } );
    $shipment->shipment_items->update( { unit_price => 1 } );

    my $customer    = $order->customer;
    $order->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );
    $customer->update( { category_id => $test->{hp_cat}->id } );
    $mech->order_nr($order->order_nr);

    #got to order view page
    $mech->order_view_url;

    # Go to the Edit Shipping Address page
    $mech->follow_link_ok({ text_regex => qr/Edit Shipping Address/ });

    $mech->submit_form_ok(
        { form_name => 'new_address', button => 'submit' },
        "Submit to Create New Address"
    );

    # Pick another US address
    my $address_hash = {
        first_name => 'Barack',
        last_name  => 'Obama',
        %{Test::Role::Address::valid_address->{US}},
    };

    # Fill the target address
    $mech->submit_form_ok({
        with_fields => $address_hash,
        button      => 'submit'
    }, 'Update the address ');
    $mech->no_feedback_error_ok;
    $mech->submit_form_ok(
        { form_name => "editAddress", button => "submit" },
        "Confirm Select Shipping Option",
    );

    $mech->submit_form_ok({
        form_name   => 'editAddress',
        button      => 'submit',
    }, 'Confirm Address' );

    $shipment->discard_changes;
    $order->discard_changes;

    $mech->get_ok( '/Finance/InvalidPayments' );
    $found = $mech->find_xpath('//td[@class="highlight4"]/a[@href="/Finance/InvalidPayments/OrderView?order_id='.$order->id.'"]');

    # Check the table has the expected order.
    my @nodes = $found->get_nodelist;
    cmp_ok( @nodes, '==', 1, "Order: ".$order->id." is in Table " );

    # Get all the tags in the current table row.
    my @table_row = $nodes[0]
        ->parent        # TD tag
        ->parent        # TR tag
        ->content_list; # TR content

    # Check we have the right number of columns.
    cmp_ok( @table_row, '==', 5, 'Table contains the correct number of columns' );

    # Check the last column is correct.
    my ( $last_update ) = $table_row[4]->content_list;
    ok( defined $last_update, 'Last update column is defined' );
    isnt( $last_update, 'Unknown', 'Last update column is not Unknown' );
    like( $last_update, qr/\d\d-\d\d-\d\d \d\d:\d\d/, 'Last update column looks like a date' );

    # Check the Order::Payment flag.
    cmp_ok ($order->payments->first->valid, "==", 0 , "Payment Valid flag is set to False");

}

Test::Class->runtests;
