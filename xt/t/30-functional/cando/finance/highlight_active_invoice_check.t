#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

highlight_active_invoice_check.t

=head1 DESCRIPTION

Verifies that customer class column appears in correct column on Active
Invoice page and that invoices for orders with Premier shipments are correctly
highlighted. Also checks that refund_warn highlight is present where it should
be.

#TAGS needsrefactor xpath finance cando

=cut

use FindBin::libs;

use Test::XTracker::Data;
use Test::Most;

use base 'Test::Class';

# CANDO-65
use Carp::Always;
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
                                    :authorisation_level
                                    :currency
                                    :shipment_status
                                    :shipment_type
                                    :order_status
                                    :customer_category
                                    :renumeration_type
                                    :renumeration_class
                                    :renumeration_status

                                );
use Test::XTracker::Mechanize;
use Test::Exception;

sub create_order {
    my ( $self, $args ) = @_;

    my $pids_to_use = $args->{pids_to_use};
    my ($order)     = Test::XTracker::Data->apply_db_order({
        pids => $self->{pids},
        attrs => [ { price => $args->{price} }, ],
        base => {
            tenders => $args->{tenders},
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        },
    });

    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$order->shipments->first->id;
    return $order;
}

sub startup : Tests(startup) {
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

    $test->{mech}   = Test::XTracker::Mechanize->new;
    $test->_setup_app_perms;
    $test->{mech}->do_login;
}

sub test_active_invoices : Tests {
    my $test = shift;
    my $mech        = $test->{mech};
    my $hp_class    = $test->{hp_class};
    my $hp_cat      = $test->{hp_cat};

    # number of columns in the table minus 1 which
    # will be the first one which is the Order Nr.
    my $cols        = 9 - 1;
    my $cat_col     = 0;        # the column the category wil be in after the Order Nr. column

    my $found;
    my @row;

    my $order       = $test->create_order();
    my $schema  = Test::XTracker::Data->get_schema;
    my $operator = $schema->resultset('Public::Operator')->search( { username => 'it.god' } )->first;
    my $renumeration = $order->shipments->first->create_related( 'renumerations', {
                    invoice_nr => '',
                    renumeration_type_id => $RENUMERATION_TYPE__CARD_DEBIT,
                    renumeration_class_id => $RENUMERATION_CLASS__RETURN,
                    renumeration_status_id => $RENUMERATION_STATUS__AWAITING_ACTION,
                    currency_id => $CURRENCY__GBP,
                    misc_refund => 50,
                } );

    $renumeration->create_related( 'renumeration_status_logs', {
                    renumeration_status_id  => $RENUMERATION_STATUS__AWAITING_ACTION,
                    operator_id             => $operator->id,
                } );

    note "Invoice Id: ".$renumeration->id;

    my $shipment    = $order->get_standard_class_shipment;
    my $customer    = $order->customer;
    $order->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );

    note "Test there is no highlight and no category shown for a Normal Order";
    $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

    $mech->get_ok( '/Finance/ActiveInvoices' );
    $found  = $mech->find_xpath('//td[@class]/a[@href="/Finance/ActiveInvoices/OrderView?order_id='.$order->id.'"]');
    ok( !scalar($found->get_nodelist), "Order: ".$order->id." is in Table with no class of highlight" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    $row[$cat_col] =~ s/[^A-Za-z0-9]//g;       # get rid of any wierd characters
    is( $row[$cat_col], "", "No Category Shown in Table Row for a 'None' Customer Category" );     # category should be first column after Order Nr.

    note "Test row highlight is correct for High Priority Customer";

    # Force the Customer to be a High Priority Customer
    $customer->update( { category_id => $hp_cat->id } );

    $mech->get_ok( '/Finance/ActiveInvoices' );
    $found  = $mech->find_xpath('//td[@class="highlight4"]/a[@href="/Finance/ActiveInvoices/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'highlight4'" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    is( $row[$cat_col], $hp_cat->category, "Category Shown in Table Row as expected: ".$hp_cat->category );

    note "Test row highlight is correct for Premier Order";

    $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER } );
    $mech->get_ok( '/Finance/ActiveInvoices' );
    $found  = $mech->find_xpath('//td[@class="highlight"]/a[@href="/Finance/ActiveInvoices/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'highlight'" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    is( $row[$cat_col], $hp_cat->category, "Category Shown in Table Row as expected: ".$hp_cat->category );

    note "Test row warning is correct ";

    $renumeration->update( { sent_to_psp => 1 } );
    $mech->get_ok( '/Finance/ActiveInvoices' );
    $found  = $mech->find_xpath('//td[@class="refund_warn"]/a[@href="/Finance/ActiveInvoices/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'refund_warn'" );
}

sub _setup_app_perms {
    my $self    = shift;

    Test::XTracker::Data->set_department('it.god', 'Finance');
    Test::XTracker::Data->grant_permissions( 'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
    Test::XTracker::Data->grant_permissions( 'it.god', 'Finance', 'Active Invoices', $AUTHORISATION_LEVEL__OPERATOR );
}

Test::Class->runtests;
