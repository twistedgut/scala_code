#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

customer_view_page.t - Tests various elements of the Customer View page

=head1 DESCRIPTION

Currently this tests the following:

    * That no Delivery Required options appears on the page (and also on the Order View page)
    * That the Finance Watch section on the Order View page is displayed when the Customer has Watch flags set
    * Can update the Customer Category
    * That can update one of the Marketing Options (used to be called Customer Options)
    * That Alternative Accounts are being displayed
    * That in the Order History section the Application Source is displayed (if there is one)
    * That in the Order History section Premier Orders are Higlighted


Please use this test for general Customer View page operations and add to the above list if you add more tests.

#TAGS customerview orderview xpath cando

=cut



use Data::Dump  qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];
use Test::XT::Flow;

use XTracker::Config::Local             qw( config_var sys_config_var );
use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :customer_category
                                            :department
                                            :flag
                                            :shipment_type
                                        );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

#--------- Tests ----------------------------------------------
_test_customer_view_page( $schema, 1 );
#--------------------------------------------------------------

done_testing;

#-----------------------------------------------------------------

=head1 METHODS

=head2 _test_customer_view_page

    _test_customer_view_page( $schema, $ok_to_do_flag );

This tests that on the 'Customer View' and 'Order View' pages that the 'Delivery Options: no signature required' option is
no longer displayed, because it was never used anyway and might cause confusion now with the new option on the Shipment.
Also tests that you can still update the Marketing Contact and Customer Category fields and Alternative Accounts are being
displayed.

This function does all of the other tests mentioned in the Description as well.

=cut

sub _test_customer_view_page {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_customer_view_page", 1       if ( !$oktodo );

        note "TESTING Customer View page";

        # set-up alternative Customer record
        my $alternative = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Data::Customer',
                'Test::XT::Data::Channel',
            ],
        );

        $alternative->channel( Test::XTracker::Data->channel_for_out );
        my $alt_customer    = $alternative->customer;
        my $alt_cust_id     = $alt_customer->id;
        my $email_addr      = 'test.'.$alt_customer->id.'@test.com';        # email address used to link 2 customers
        $alt_customer->update( {
                            email   => $email_addr,
                            category_id => $CUSTOMER_CATEGORY__EIP_PREMIUM,
                            no_marketing_contact => undef,
                            no_signature_required => 0,
                        } );

        my $framework   = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::Fulfilment',
                'Test::XT::Flow::CustomerCare',
                'Test::XT::Data::Customer',
                'Test::XT::Data::Channel',
            ],
        );
        $framework->channel( Test::XTracker::Data->channel_for_nap );

        # Make sure none of the accounts have URNs, as we're not testing
        # Seaview in this test.
        $framework->account_urn( undef );
        $alternative->account_urn( undef );

        my $orddetails  = $framework->flow_db__fulfilment__create_order(
                                                channel => $framework->channel,
                                                products => 1,
                                            );
        my $order   = $orddetails->{order_object};

        my $app_name = 'App';
        my $app_ver  = '1.4';
        my $expected_app_source = $app_name.' '.$app_ver;

        $schema->resultset('Public::OrderAttribute')->create({
            orders_id           => $order->id,
            source_app_name    => $app_name,
            source_app_version => $app_ver
        });
        $order->discard_changes;

        # get a new customer record and use this for
        # the order instead of whatever it has found
        my $customer= $framework->customer;
        # set-up some data first
        $customer->update( {
                            email => $email_addr,       # link to the other Alternative Customer
                            category_id => $CUSTOMER_CATEGORY__PRESS_CONTACT,
                            no_marketing_contact => undef,
                            no_signature_required => 0,
                        } );
        # put the customer on Finance Watch so the relevant
        # section will appear on the Order View page
        $customer->create_related( 'customer_flags', { flag_id => $FLAG__FINANCE_WATCH } );
        $order->update( { customer_id => $customer->id } );

        Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                ]
            }
        } );

        # Make sure the customer has no customer_actions (so the checkbox will be displayed).
        $customer->customer_actions->delete;
        cmp_ok( $customer->customer_actions->count, '==', 0, "The customer has no customer_action records" );

        # check Delivery Options aren't on the Order View page
        $framework->flow_mech__customercare__orderview( $order->id );
        my $data    = $framework->mech->as_data->{meta_data};
        ok( exists( $data->{'Customer Information'} ), "Found 'Customer Information' table on Order View page" );
        ok( !exists( $data->{'Customer Information'}{'Delivery Options'} ), "Did NOT Find 'Delivery Options' in the table" );

        $framework->errors_are_fatal(0);    # avoid know error communicating with Stomp on the Customer View page

        # Make sure we get get an error when there are no parameters.
        $framework->mech->get_ok( '/CustomerCare/CustomerSearch/CustomerView' );
        $framework->mech->has_feedback_error_ok( 'No customer record could be found' );

        # Make sure we get get an error when the parameter for the value is missing.
        $framework->mech->get_ok( '/CustomerCare/CustomerSearch/CustomerView?customer_id=' );
        $framework->mech->has_feedback_error_ok( 'No customer record could be found' );

        # go to the Customer View page
        $framework->flow_mech__customercare__customerview( $customer->id );
        $framework->mech->no_feedback_error_ok;
        $data = $framework->mech->as_data;

        # Check the 'New High Value' checkbox is present and not the image (tick).
        ok( ! exists $data->{new_high_value_image}, 'new_high_value_image image does not exist' );
        ok( exists $data->{new_high_value}, 'new_high_value checkbox exists' );

        $data = $data->{page_data};

        # Check customer fields are present
        my @customer_fields = sort ('Cust No.', 'Category', 'Title', 'Name', 'Email', 'DOB');
        my @found_fields = sort keys %{$data->{customer_details}->[0]};
        is_deeply (\@customer_fields, \@found_fields, 'All customer fields are present');

        # Check for app source
        is($data->{order_history}{data}[0]{'App Source'}, $expected_app_source, 'App source correct');

        # check Delivery Options aren't on the Customer View page
        ok( exists( $data->{customer_options} ), "Found 'Marketing Options' table on Customer View page" );
        ok( !exists( $data->{customer_options}{data}{'Delivery Options'} ), "Did NOT Find 'Delivery Options' in the table" );

        note "check Alternative Accounts";
        my $alt_accounts    = $data->{alternative_accounts};
        cmp_ok( @{ $alt_accounts }, '==', 1, "Found 1 Alternative Account as Expected" );
        my $account = $alt_accounts->[0];
        is( $account->{Category}, 'EIP Premium', "Alt Acc Category is 'EIP Premium'" );
        is( $account->{'Sales Channel'}, $alt_customer->channel->name, "Alt Acc Channel is '".$alt_customer->channel->name."'" );
        is( $account->{'Customer Number'}{value}, $alt_customer->is_customer_number, "Alt Acc Customer Number is '".$alt_customer->is_customer_number."'" );
        like( $account->{'Customer Number'}{url}, qr{/CustomerView\?customer_id=$alt_cust_id}, "Alt Acc Link URL has the Correct Id in it: $alt_cust_id" );

        note "check Customer Category when you can and can't edit it";
        is( $data->{customer_details}[0]{Category}, 'Press Contact', "Customer Category shown is 'Press Contact'" );

        note "Re-load page but with Department set so the Customer Category can be edited";
        Test::XTracker::Data->set_department( 'it.god', 'Personal Shopping' );
        $framework->flow_mech__customercare__customerview( $customer->id );
        $data   = $framework->mech->as_data->{page_data};
        cmp_ok( $data->{customer_details}[0]{Category}{select_selected}[0], '==', $CUSTOMER_CATEGORY__PRESS_CONTACT, "Customer Category 'selected' in field is 'Press Contact'" );

        note "update a Marketing Option";
        $framework->flow_mech__customercare__customerview_update_options( { marketing_contact => '2month' } )
                    ->mech->has_feedback_success_ok( qr/Marketing Options Updated/ );
        $customer->discard_changes;
        $alt_customer->discard_changes;     # check that only one customer record has been updated
        ok( defined $customer->no_marketing_contact, "Customer 'no_marketing_contact' field now has a value" );
        cmp_ok( $customer->no_signature_required, '==', 0, "Customer 'no_signature_required' field is still FALSE" );
        cmp_ok( $customer->category_id, '==', $CUSTOMER_CATEGORY__PRESS_CONTACT,, "Customer's Category is Still 'Press Contact'" );
        ok( !defined $alt_customer->no_marketing_contact, "Alt Customer 'no_marketing_contact' field is still NULL" );

        note "update a Customer Category";
        $framework->flow_mech__customercare__customerview_update_category( 'EIP' )
                    ->mech->has_feedback_success_ok( qr/Customer Category Updated/ );
        $customer->discard_changes;
        $alt_customer->discard_changes;     # check that only one customer record has been updated
        cmp_ok( $customer->category_id, '==', $CUSTOMER_CATEGORY__EIP, "Customer's Category is now 'EIP'" );
        cmp_ok( $customer->no_signature_required, '==', 0, "Customer 'no_signature_required' field is still FALSE" );
        ok( defined $customer->no_marketing_contact, "Customer 'no_marketing_contact' field Still has a value" );
        cmp_ok( $alt_customer->category_id, '==', $CUSTOMER_CATEGORY__EIP_PREMIUM, "Alt Customer's Category is Still 'EIP Premium'" );

        note "update Marketing Option back to being NULL";
        $framework->flow_mech__customercare__customerview_update_options( { marketing_contact => undef } )
                    ->mech->has_feedback_success_ok( qr/Marketing Options Updated/ );
        $customer->discard_changes;
        ok( !defined $customer->no_marketing_contact, "Customer 'no_marketing_contact' field is now NULL" );

        $framework->errors_are_fatal(1);    # restore checking for errors

        note "update Marketing Option 'New High Value' to TRUE";
        $framework->flow_mech__customercare__customerview_update_options( { marketing_high_value => 1 } )
                    ->mech->has_feedback_success_ok( qr/Marketing Options Updated/ );

        $data = $framework->mech->as_data;
        cmp_ok( $customer->customer_actions->count, '==', 1, "A customer_action record has been created" );
        ok( exists $data->{new_high_value_image}, 'new_high_value_image image exists' );
        ok( ! exists $data->{new_high_value}, 'new_high_value checkbox does not exist' );

        $framework->errors_are_fatal(0);

        note "update Marketing Option 'New High Value' to TRUE .. AGAIN (it should fail)";
        my $is_customer_number = $customer->is_customer_number;
        $framework->flow_mech__customercare__customerview_update_options( { marketing_high_value => 1 } )
                    ->mech->has_feedback_error_ok( qr/.*Customer $is_customer_number already has a 'New High Value' flag.*/ );

        $framework->errors_are_fatal(1);    # restore checking for errors

        note "checking that Premier orders are highlighted";
        my $shipment = $order->get_standard_class_shipment;
        my $xpath = './/table[contains(@id,"tbl_order_history_min")]/tr[contains(@class,"highlight")]/td/a[@href="/CustomerCare/CustomerSearch/OrderView?order_id='.$order->id.'"]';
        my $found;

        # set the shipment type NOT Premier
        $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__DOMESTIC } );

        $framework->flow_mech__customercare__customerview( $customer->id );
        $found = $framework->mech->find_xpath($xpath);
        ok( !scalar($found->get_nodelist), "Order: ".$order->id." is in Table row with no class of highlight" );

        # now set shipment type to Premier
        $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER } );

        $framework->flow_mech__customercare__customerview( $customer->id );
        $found = $framework->mech->find_xpath($xpath);
        ok( scalar($found->get_nodelist), "Order: ".$order->id." is in Table row with a Class of 'highlight'" );

    };

    return;
}

#-----------------------------------------------------------------
