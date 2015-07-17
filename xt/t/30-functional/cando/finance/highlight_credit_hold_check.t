#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

highlight_credit_hold_check.t - Tests Credit Hold and Credit Check Pages

=head1 DESCRIPTION

Verifies that held order shows on Credit Hold page and that customer category
is correctly displayed with row highlighted if customer is priority or shipment
is Premier.

For Credit Check page verifies the above plus verifies that the customer
preferred language is correctly displayed.

#TAGS needsrefactor xpath cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::AccessControls;

use base 'Test::Class';

use Carp::Always;
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
                                    :authorisation_level
                                    :shipment_status
                                    :shipment_type
                                    :order_status
                                    :customer_category
                                );
use Test::XTracker::Mechanize;
use Test::XT::Flow;


sub create_order {
    my ( $self, $args ) = @_;

    my $pids_to_use = $args->{pids_to_use};
    my ($order)     = Test::XTracker::Data->apply_db_order({
        pids => $self->{pids},
        attrs => [ { price => $args->{price} }, ],
        base => {
            tenders => $args->{tenders},
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
            shipment_status => $SHIPMENT_STATUS__FINANCE_HOLD,
        },
    });
    $order->shipments->first->renumerations->delete;

    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$order->shipments->first->id;
    return $order;
}

sub startup : Tests( startup => no_plan ) {
    my $test = shift;
    $test->{schema} = Test::XTracker::Data->get_schema;

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap',
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
            '/Finance/CreditHold%',
            '/Finance/CreditCheck',
        ],
        main_nav => [
            'Customer Care/Order Search',
        ],
    } );
}

sub shut_down : Tests(shutdown) {
    Test::XTracker::Data::AccessControls->restore_build_main_nav_setting;
}

=head2 test_credit_hold

Verifies that held order shows on Credit Hold page and that customer category
is correctly displayed with row highlighted if shipment is Premier.

=cut

sub test_credit_hold : Tests {
    my $test = shift;
    my $mech        = $test->{mech};
    my $hp_class    = $test->{hp_class};
    my $hp_cat      = $test->{hp_cat};

    # number of columns in the table minus 1 which
    # will be the first one which is the Order Nr.
    my $cols        = 12;
    my $cat_col     = 1;        # the column the category wil be in after the Order Nr. column
    my $country_col = 4;        # the column with the Shipping Country in it after the Order Nr. column

    my $found;
    my @row;

    my $order       = $test->create_order();
    my $shipment    = $order->get_standard_class_shipment;
    my $ship_country= $shipment->shipment_address->country;
    my $customer    = $order->customer;
    $order->update( { order_status_id => $ORDER_STATUS__CREDIT_HOLD } );

    note "Test there is no highlight and no category shown for a Normal Order";
    $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

    $mech->get_ok( '/Finance/CreditHold' );
    $found  = $mech->find_xpath('//td[ contains(@class, "hightlight") ]/a[@href="/Finance/CreditHold/OrderView?order_id='.$order->id.'"]');
    ok( !scalar($found->get_nodelist), "Order: ".$order->id." is in Table with no class of highlight" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    $row[$cat_col] =~ s/[^A-Za-z0-9]//g;       # get rid of any wierd characters
    is( $row[$cat_col], "", "No Category Shown in Table Row for a 'None' Customer Category" );     # category should be first column after Order Nr.


    # Set customer_category to 'Hot Contact - Client Relations'
    $customer->update( { category_id => $CUSTOMER_CATEGORY__HOT_CONTACT__DASH__CLIENT_RELATIONS } );
    $mech->get_ok( '/Finance/CreditHold' );
    $found  = $mech->find_xpath('//td[@class="highlight4"]/a[@href="/Finance/CreditHold/OrderView?order_id='.$order->id.'"]');
    ok( !scalar($found->get_nodelist), "Order: ".$order->id." is in Table with no class of highlight" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    $row[$cat_col] =~ s/[^A-Za-z0-9]//g;       # get rid of any wierd characters
    is( $row[$cat_col], 'HotContactClientRelations', "Category 'Hot Contact - Client Relations' is Shown in Table Row as expected");

    note "Test row highlight is correct for High Priority Customer";

    # Force the Customer to be a High Priority Customer
    $customer->update( { category_id => $hp_cat->id } );

    $mech->get_ok( '/Finance/CreditHold' );
    $found  = $mech->find_xpath('//td[@class="highlight4"]/a[@href="/Finance/CreditHold/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'highlight4'" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    is( $row[$cat_col], $hp_cat->category, "Category Shown in Table Row as expected: ".$hp_cat->category );

    note "Test row highlight is correct for Premier Order";

    $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER } );
    $mech->get_ok( '/Finance/CreditHold' );
    $found  = $mech->find_xpath('//td[@class="highlight"]/a[@href="/Finance/CreditHold/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'highlight'" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    is( $row[$cat_col], $hp_cat->category, "Category Shown in Table Row as expected: ".$hp_cat->category );
    like( $row[$country_col], qr/$ship_country/, "Shipping Country Shown in Table Row as expected: ".$ship_country );
}

sub test_credit_check : Tests {
    my $test = shift;
    my $mech        = $test->{mech};
    my $hp_class    = $test->{hp_class};
    my $hp_cat      = $test->{hp_cat};

    # number of columns in the table, plus two hidden value
    # columns, minus 1 which will be the first one which is the
    # Order Nr.
    my $cols        = 17;
    my $cat_col     = 1;        # the column the category wil be in after the Order Nr. column
    my $country_col = 3;        # the column with the Shipping Country in it after the Order Nr. column
    my $lang_col    = 15;       # the column the Customer's Preferred Language will be in

    my $found;
    my @row;

    my $order       = $test->create_order();
    my $shipment    = $order->get_standard_class_shipment;
    my $ship_country= $shipment->shipment_address->country;
    my $customer    = $order->customer;
    $order->update( { order_status_id => $ORDER_STATUS__CREDIT_CHECK } );

    $customer->customer_attribute->delete       if ( $customer->customer_attribute );
    my $default_language    = $test->{schema}->resultset('Public::Language')
                                                ->get_default_language_preference
                                                    ->code;

    note "Test there is no highlight and no category shown for a Normal Order";
    $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

    $mech->get_ok( '/Finance/CreditCheck' );
    $found  = $mech->find_xpath('//td[ contains(@class, "hightlight") ]/a[@href="/Finance/CreditCheck/OrderView?order_id='.$order->id.'"]');
    ok( !scalar($found->get_nodelist), "Order: ".$order->id." is in Table with no class of highlight" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    $row[$cat_col] =~ s/[^A-Za-z0-9]//g;       # get rid of any wierd characters
    is( $row[$cat_col], "", "No Category Shown in Table Row for a 'None' Customer Category" );     # category should be first column after Order Nr.
    like( $row[ $lang_col ], qr/^${default_language}$/i, "Default Language Code is Displayed on page: '${default_language}'" );

    note "Test row highlight is correct for High Priority Customer";

    # Force the Customer to be a High Priority Customer
    $customer->update( { category_id => $hp_cat->id } );
    # set the Customer's Language to be 'French' who's code is 'FR'
    $customer->set_language_preference('FR');

    $mech->get_ok( '/Finance/CreditCheck' );
    $found  = $mech->find_xpath('//td[@class="highlight4"]/a[@href="/Finance/CreditCheck/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'highlight4'" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    is( $row[$cat_col], $hp_cat->category, "Category Shown in Table Row as expected: ".$hp_cat->category );
    like( $row[ $lang_col ], qr/^FR$/i, "Language Code for 'French' is Displayed on page: 'FR'" );

    note "Test row highlight is correct for Premier Order";

    $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER } );
    $mech->get_ok( '/Finance/CreditCheck' );
    $found  = $mech->find_xpath('//td[@class="highlight"]/a[@href="/Finance/CreditCheck/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'highlight'" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    is( $row[$cat_col], $hp_cat->category, "Category Shown in Table Row as expected: ".$hp_cat->category );
    like( $row[$country_col], qr/$ship_country/, "Shipping Country Shown in Table Row as expected: ".$ship_country );
}

Test::Class->runtests;
