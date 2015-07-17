#!/usr/bin/env perl

use NAP::policy qw(class tt test);

BEGIN {
    extends "NAP::Test::Class";
}

=head1 NAME

invalidpayments.t - Tests Finance / InvalidPayments page

=head2 DESCRIPTION

Verifies that entries on the page are correctly highlighted for priority
customers and premier shipments and that the customer category is correctly
displayed.

#TAGS needsrefactor xpath finance cando

=cut

use Test::XTracker::Data;

# CANDO-132
use Carp::Always;
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw(
                                    :authorisation_level
                                    :currency
                                    :shipment_status
                                    :shipment_type
                                    :order_status
                                    :customer_category

                                );
use Test::XTracker::Mechanize;
use Test::Exception;

sub create_order {
    my ( $self, $args ) = @_;

    my $pids_to_use = $args->{pids_to_use};
    my ($order) = Test::XTracker::Data->apply_db_order({
        pids => $self->{pids},
        attrs => [ { price => $args->{price} }, ],
        base => {
            tenders => $args->{tenders},
            shipment_type => $SHIPMENT_TYPE__DOMESTIC,
        },
    });

    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    note "Shipment Id: ".$order->shipments->first->id;

    # let's make it fail payment
    my $schema  = Test::XTracker::Data->get_schema;
    my $max_payment = $schema->resultset('Orders::Payment')->search(
        {
            'length(preauth_ref)' => { '<' => 10 },
            preauth_ref => { '~' => '^[0-9]+$' },
            settle_ref => { '~' => '^[0-9]+$' },
        },
        {
            select => [
                { max => 'psp_ref' },
                { max => 'preauth_ref::integer' },
                { max => 'settle_ref::integer' },
            ],
            as => [qw(
                psp_ref
                preauth_ref
                settle_ref
            )],
        }
    )->single;
    Test::XTracker::Data->create_payment_for_order( $order, {
        psp_ref     => (($max_payment->psp_ref()||'') . 'X'),
        preauth_ref => (($max_payment->preauth_ref()||0) + 1),
        settle_ref  => (($max_payment->settle_ref()||0) + 1),
        fulfilled   => 0,
        valid       => 0,
    } );
    return $order;
}

sub startup : Tests(startup => no_plan) {
    my $test = shift;

    $test->SUPER::startup;

    use_ok 'Test::XT::Flow';
    use_ok 'Test::XTracker::Data';

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

    $test->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Finance',
        ],
    );
}

sub test_invalid_payments : Tests {
    my $test = shift;
    my $mech        = $test->{mech};
    my $hp_class    = $test->{hp_class};
    my $hp_cat      = $test->{hp_cat};
    my $schema      = $test->{schema};

    # number of columns in the table minus 1 which
    # will be the first one which is the Order Nr.
    my $cols        = 5 - 1;
    my $cat_col     = 0;        # the column the category wil be in after the Order Nr. column

    my $found;
    my @row;

    # Create an order with failed payment
    my $order       = $test->create_order();

    my $operator = $schema->resultset('Public::Operator')->search( { username => 'it.god' } )->first;

    my $shipment    = $order->get_standard_class_shipment;

    my $customer    = $order->customer;
    $order->update( { order_status_id => $ORDER_STATUS__ACCEPTED } );

    note "Test there is no highlight and no category shown for a Normal Order";
    $customer->update( { category_id => $CUSTOMER_CATEGORY__NONE } );

    $mech->set_session_roles( '/Finance/InvalidPayments' );
    $mech->get_ok( '/Finance/InvalidPayments' );
    $found  = $mech->find_xpath('//td[@class]/a[@href="/Finance/InvalidPayments/OrderView?order_id='.$order->id.'"]');
    ok( !scalar($found->get_nodelist), "Order: ".$order->id." is in Table with no class of highlight" );

    cmp_ok($order->payments->first->valid, "==",0, "In 'order.payment' valid  flag is set to FALSE");
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    $row[$cat_col] =~ s/[^A-Za-z0-9]//g;       # get rid of any wierd characters
    is( $row[$cat_col], "", "No Category Shown in Table Row for a 'None' Customer Category" );     # category should be first column after Order Nr.

    note "Test row highlight is correct for High Priority Customer";

    # Force the Customer to be a High Priority Customer
    $customer->update( { category_id => $hp_cat->id } );

    $mech->get_ok( '/Finance/InvalidPayments' );
    $found  = $mech->find_xpath('//td[@class="highlight4"]/a[@href="/Finance/InvalidPayments/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'highlight4'" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    is( $row[$cat_col], $hp_cat->category, "Category Shown in Table Row as expected: ".$hp_cat->category );

    note "Test row highlight is correct for Premier Order";

    $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER } );
    $mech->get_ok( '/Finance/InvalidPayments' );
    $found  = $mech->find_xpath('//td[@class="highlight"]/a[@href="/Finance/InvalidPayments/OrderView?order_id='.$order->id.'"]');
    ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table with a Class of 'highlight'" );
    @row    = $mech->get_table_row( $order->order_nr );     # get values in the row following Order Nr.
    cmp_ok( @row, '==', $cols, "Found $cols other columns in Table Row" );
    is( $row[$cat_col], $hp_cat->category, "Category Shown in Table Row as expected: ".$hp_cat->category );
}

sub _setup_app_perms {
    my $self    = shift;

    Test::XTracker::Data->set_department('it.god', 'Finance');
    Test::XTracker::Data->grant_permissions( 'it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR );
    Test::XTracker::Data->grant_permissions( 'it.god', 'Finance', 'Invalid Payments', $AUTHORISATION_LEVEL__OPERATOR );
}

=head2 test__check_acl_protection

Test the ACL protection on the /Finance/Invalid Payments page

Steps:
    1. Accessing the page without any roles assigned should fail
    2. Accessing the page with an incorrect role assigned should fail
    3. Accessing the page with the required role should succeed

=cut

sub test__check_acl_protection : Tests() {
    my $self = shift;

    my $framework = $self->{framework};

    note 'Logging in with no roles or department ..';

    $framework->login_with_permissions( {
        # start with no roles
        roles => {},
        # make sure the role is undef as it shouldn't be required for this page
        dept => undef,
    } );

    note 'Accessing the /Finance/InvalidPayments page with no roles should fail ..';

    $framework->catch_error(
        qr/don't have permission to/i,
        q{Can't access the /Finance/InvalidPayments page},
        flow_mech__finance__invalid_payments => ()
    );

    note 'Setting an incorrect role in the session ..';

    $framework->{mech}->set_session_roles( '/CustomerCare/CustomerCategory' );

    note 'Accessing the /Finance/InvalidPayments page with invalid roles..';

    $framework->catch_error(
        qr/don't have permission to/i,
        q{Can't access the /Finance/InvalidPayments page},
        flow_mech__finance__invalid_payments => ()
    );

    note 'Setting the correct roles in the session';

    $framework->{mech}->set_session_roles( '/Finance/InvalidPayments' );

    note 'Now accessing the page should succeed ..';

    $framework->flow_mech__finance__invalid_payments;
    $framework->{mech}->no_feedback_error_ok;
}

Test::Class->runtests;
