#!/usr/bin/env perl
use NAP::policy "tt", 'test';

=head1 NAME

markdown.t - Takes Markdowns into Consideration when Creating a Gratuity Refund Invoice

=head1 DESCRIPTION

This test does the following using the 'Create Credit/Debit' left hand menu option
on the Order View page:

    1) UI : Test "Stock Qty" column is there on 'Create Credit/Debit' page
    2) test value of stock avilable is correct
    3) Test markdown calculation are correct
    4) test tax is refunded correctly as per country

#TAGS finance invoice customercare refund cando

=cut


use Test::XTracker::Data;
use Test::XT::Flow;
use Test::XTracker::Mechanize;
use XTracker::Config::Local qw( config_var );
use XTracker::Database::Stock qw( get_saleable_item_quantity );
use XTracker::Constants::FromDB qw(:authorisation_level :refund_charge_type);
use DateTime;
use DateTime::Duration;
use Data::Dumper;

my $schema    = Test::XTracker::Data->get_schema;
my $framework = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Flow::CustomerCare',
            ],
        );

my $dbh = $schema->storage->dbh;
Test::XTracker::Data->set_department( 'it.god', 'Finance' );
$framework->login_with_permissions({
        perms => { $AUTHORISATION_LEVEL__MANAGER => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search'
                    ]}
                });


#---------TESTS---------------------------------------------------
_test_markdown_calculation( $schema, 1 );
_test_tax_refund_for_markdown( $schema, 1);
#-----------------------------------------------------------------
done_testing;
#-----------------------------------------------------------------


=head1 METHODS

=head2 _test_markdown_calculation

    _test_markdown_calculation( $schema, $ok_to_do_flag );

Tests that the Stock Qty column is shown on the page with the correct value, also
checks to make sure that the Markdown has been taken into consideration in what
can be Refunded.

=cut

sub _test_markdown_calculation {
    my( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_test_create_invoice_page", 1 if( !$oktodo);

        note "TESTING Markdown calculation";

        my ($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
          });
        isa_ok( my $product = $pids->[0]{product}, 'XTracker::Schema::Result::Public::Product' );

        # Using DC's country so that tax will get refunded.
        my $address = Test::XTracker::Data->order_address( { address=>'create', country => config_var( 'DistributionCentre', 'country' ) } );

        my $order_orig = {
            shipping_charge => '19.57',
            items => {
                $pids->[0]{sku} => { price => 200.00, tax => '10.00', duty => '5.00' },
            },
            invoice_address_id => $address->id,
        };


        my $order = _create_order_with_price_adjustment($schema,$order_orig, $product);
        my $shipment    = $order->shipments->first;
        my @items   = $shipment->shipment_items->all;
        my $ship_item   = $shipment->shipment_items->first;
        my $invoice_reason = $schema->resultset('Public::RenumerationReason')->first;

        my $page_data = _create_CreditDebit_page( $framework, $order->id, $shipment->id);

        # Check if Stock qty column exist
        ok(exists $page_data->{refund_value}[0]->{'StockQty'}, "Stock Qty column appears");

        # Check if size column exist
        ok(exists $page_data->{refund_value}[0]->{'Size'}, "Size column appears");
        my $size = $ship_item->variant->designer_size->size;
        cmp_ok($page_data->{refund_value}[0]->{'Size'}, 'eq', $size, "Size value is correct" );

        # Check if stock value displayed is correct
        my $stock = get_saleable_item_quantity( $dbh, $product->id);
        $stock = $stock->{$channel->name}->{$ship_item->variant_id};
        cmp_ok( $page_data->{refund_value}[0]->{'StockQty'}->{value}, '==', $stock, "Stock Qty value is correct" );

        # Check if [Markdown -> Applied] column exists.
        ok(exists $page_data->{refund_value}[0]->{Applied},
            '[Markdown -> Applied] column appears');

        cmp_ok( $page_data->{refund_value}[0]->{Applied}->{value},
            '==', '10.00', '[Markdown -> Applied] value is correct' );

        # Check if [Markdown -> Current] column exists.
        ok(exists $page_data->{refund_value}[0]->{Current},
            '[Markdown -> Current] column appears');

        cmp_ok( $page_data->{refund_value}[0]->{Current}->{value},
            '==', '25.00', '[Markdown -> Current] value is correct' );

        # Click on apply checkbox button and submit
        my $shipment_item_id = $ship_item->id;
        $framework->flow_mech__customercare___refundForm_submit( {
                                        "apply_$shipment_item_id"  => 1,
                                        invoice_reason => $invoice_reason->id,
                                });
        $page_data = $framework->mech->as_data();

        # Check "Applied Stock" column is there on confirmed Page
        ok(exists $page_data->{refund_value}[1]->{'StockQty'}, "Stock Qty column appears on Confirm Page");
        cmp_ok( $page_data->{refund_value}[1]->{'StockQty'}, '==', $stock, "Stock Qty value is correct on Confirm Page" );

        # check calculations
        # calculated markdown = 25 percent of original unit price - 10 percent of original unit price
        # 222.22(original order value) * (25/100) - 222.22* (10/100) = 33.33
        cmp_ok( $page_data->{refund_value}[1]->{'Unit Price'}->{value}, '==', 33.33, "Calculated markdown is correct" );

        $framework->flow_mech__customercare__refundForm_confirm_submit();

        #check renumeration table for Unit_price, tax and duty
        my ($renumeration_id) = ($framework->mech->uri =~ /invoice_id=(\d*)/ );
        note "Created Invoice Id: $renumeration_id\n";
        my $renum_info = $schema->resultset('Public::RenumerationItem')->find({ renumeration_id => $renumeration_id } );
        cmp_ok( $renum_info->unit_price, '==', 33.330, "Invoice has correct unit price");

        my $ship_country= $shipment->shipment_address->country_table;
        if( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX )) {
            cmp_ok($page_data->{refund_value}[1]->{Tax}->{value}, '==', 1.670, "Tax was refunded correctly");
        } else {
            cmp_ok($page_data->{refund_value}[1]->{Tax}->{value}, '==', 0.000, "Tax was refunded correctly");
        }

#        cmp_ok( $renum_info->tax, '==', 1.670, "Invoice has correct tax price");
        cmp_ok( $renum_info->duty, '==', 0.000, "Invoice has correct duty price");

    };
}

=head2 _test_tax_refund_for_markdown

    _test_tax_refund_for_markdown( $schema, $ok_to_do_flag );

Tests that the correct Tax is refunded for Items with a Markdown.

=cut

sub _test_tax_refund_for_markdown {

     my( $schema, $oktodo ) = @_;

    SKIP: {
        skip "_test_tax_refund_for_markdown", 1 if( !$oktodo);

        note "TESTING Tax refund for markdown";

        my ($channel,$pids) = Test::XTracker::Data->grab_products({how_many => 1});
        isa_ok( my $product = $pids->[0]{product}, 'XTracker::Schema::Result::Public::Product' );

        # Using DC's country so that tax will get refunded.
        my $address = Test::XTracker::Data->order_address( { address=>'create', country => config_var( 'DistributionCentre', 'country' ) } );

        my $order_orig = {
            shipping_charge => '19.57',
            items => {
                $pids->[0]{sku} => { price => 200.00, tax => '10.00', duty => '5.00' },
            },
            invoice_address_id => $address->id,
        };


        my $order = _create_order_with_price_adjustment($schema,$order_orig, $product);
        my $shipment    = $order->shipments->first;
        my @items   = $shipment->shipment_items->all;
        my $ship_item   = $shipment->shipment_items->first;
        my $invoice_reason = $schema->resultset('Public::RenumerationReason')->first;

        #got to Create Credit/Debit page
        my $page_data = _create_CreditDebit_page( $framework, $order->id, $shipment->id);

        # Click on apply checkbox button and submit
        my $shipment_item_id = $ship_item->id;
        $framework->flow_mech__customercare___refundForm_submit( {
                                        "apply_$shipment_item_id"  => 1,
                                        invoice_reason => $invoice_reason->id,
                                });
        $page_data = $framework->mech->as_data();



        my $ship_country= $shipment->shipment_address->country_table;
        if( $ship_country->can_refund_for_return( $REFUND_CHARGE_TYPE__TAX )) {
            cmp_ok($page_data->{refund_value}[1]->{Tax}->{value}, '==', 1.67, "Tax was refunded correctly");
        } else {
            cmp_ok($page_data->{refund_value}[1]->{Tax}->{value}, '==', 0.00, "Tax was refunded correctly");
        }

        # update the shipping country with the new country
        $shipment->discard_changes;
        $shipment->shipment_address->update( { country => Test::XTracker::Data->get_non_tax_duty_refund_state()->country } );

        # go to Create Credit/Debit page
        $page_data = _create_CreditDebit_page( $framework, $order->id, $shipment->id);

        # Click on apply checkbox button and submit
        $shipment_item_id = $ship_item->id;
        $framework->flow_mech__customercare___refundForm_submit( {
                                        "apply_$shipment_item_id"  => 1,
                                        invoice_reason => $invoice_reason->id,
                                });
        $page_data = $framework->mech->as_data();

        cmp_ok($page_data->{refund_value}[1]->{Tax}->{value}, '==', 0.00, "Tax refunded should be zero");

        #check for Puerto Rico

        $shipment->shipment_address->update( { country => 'Puerto Rico' });

        $page_data = _create_CreditDebit_page( $framework, $order->id, $shipment->id);

        # Click on apply checkbox button and submit
        $shipment_item_id = $ship_item->id;
        $framework->flow_mech__customercare___refundForm_submit( {
                                        "apply_$shipment_item_id"  => 1,
                                        invoice_reason => $invoice_reason->id,
                                });
        $page_data = $framework->mech->as_data();
        cmp_ok($page_data->{refund_value}[1]->{Tax}->{value}, '==', 0.00, "No Tax refund for Puerto Rico");




    };


}


=head2 _create_order_with_price_adjustment

    $dbic_order = _create_order_with_price_adjustment( $order_args, $dbic_product );

Creates an Order with a Price Adjustment.

=cut

sub _create_order_with_price_adjustment {

    my $schema     = shift;
    my $order_args = shift;
    my $product    = shift;

    my ($channel,$pids) = Test::XTracker::Data->grab_products({
            how_many => 1,
          });


    my $order = Test::XTracker::Data->create_db_order( $order_args );
    my $shipment    = $order->shipments->first;

    # Create order date and start/end dates for the past, present and future.
    my $now             = $schema->db_now;
    my $order_date      = $now->clone->subtract( days => 2 );
    my $past_start      = $now->clone->subtract( days => 3 );
    my $past_end        = $now->clone->subtract( days => 2 );
    my $current_start   = $now->clone->subtract( days => 1 );
    my $current_end     = $now->clone->add( days => 1 );
    my $future_start    = $now->clone->add( days => 2 );
    my $future_end      = $now->clone->add( days => 3 );

    $order->update( { date => $order_date } );
    $shipment->update( { date => $order_date } );

    # Clear all markdowns
    my @adjusts = $product->search_related('price_adjustments')->all;
    foreach my $adjust ( @adjusts ) {
        $adjust->link_shipment_item__price_adjustments->delete;
        $adjust->delete;
    }

    note " product id is ". $product->id;

    # Insert Price Adjustment in the past.
    my $past_adjustment = $product->create_related( price_adjustments => {
        product_id  => $product->id,
        percentage  => '10',
        exported    => 'true',
        date_start  => $past_start,
        date_finish => $past_end,
        category_id => 50
    } );

    # Insert Price Adjustment in the present.
    my $current_adjustment = $product->create_related( price_adjustments => {
        product_id  => $product->id,
        percentage  => '25',
        exported    => 'true',
        date_start  => $current_start,
        date_finish => $current_end,
        category_id => 50
    } );

    # Insert Price Adjustment in the future.
    my $future_adjustment = $product->create_related( price_adjustments => {
        product_id  => $product->id,
        percentage  => '40',
        exported    => 'true',
        date_start  => $future_start,
        date_finish => $future_end,
        category_id => 50
    } );

    note ' Record inserted (past)    : ' . $past_adjustment->id . '/' . $past_adjustment->product_id;
    note ' Record inserted (current) : ' . $current_adjustment->id . '/' . $current_adjustment->product_id;
    note ' Record inserted (future)  : ' . $future_adjustment->id . '/' . $future_adjustment->product_id;

    # get shipment items
    my @items   = $shipment->shipment_items->all;
    my $ship_item   = $shipment->shipment_items->first;
    $ship_item->create_related('link_shipment_item__price_adjustment', {
                                price_adjustment_id => $past_adjustment->id,
                              });

    return $order;

}

=head2 _create_CreditDebit_page

    _create_CreditDebit_page( $framework, $order_id, $shipment_id );

Go to the Order View page for an Order Id and then clicks on the 'Create Credit/Debit' page.

=cut

sub _create_CreditDebit_page {
    my $framework   = shift;
    my $order_id    = shift;
    my $shipment_id = shift;

    $framework->flow_mech__customercare__orderview( $order_id );
    $framework->flow_mech__customercare_create_debit_credit($order_id, $shipment_id);

    return($framework->mech->as_data());

}


=head2 setup_user_perms

    setup_user_perms();

Set-up permission to use the Order Search page.

=cut

sub setup_user_perms {

  Test::XTracker::Data->grant_permissions( 'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );

}



#-----------------------------------------------------------------
1;

