#!/usr/bin/env perl

=head1 NAME

bulkcustomercategoryupdate.t - tests CustomerCare/CustomerCategory Page

=head1 DESCRIPTION

Verifies that the bulk customer category update function works i.e. customer categories are updated in XT and in Seaview.
Tests the two customer category pages - bulk.tt and summary.tt

#TAGS cando customercategory

=cut

use NAP::policy "tt", "test", "class";
BEGIN { extends "NAP::Test::Class" }


use Test::XT::Flow;
use Test::XTracker::Data;
use XTracker::Constants::FromDB qw( :customer_category );
use Test::XT::DC::JQ;

sub startup : Test( startup => no_plan ) {
    my $self = shift;

    #Get a single channel
    my $channel = Test::XTracker::Data->any_channel->id;
    $self->{channel} = $channel;

    #Create two customers
    my $customer_one_id = Test::XTracker::Data->create_test_customer(
        channel_id => $channel,
    );
    $self->{customer_one} = $self->rs("Public::Customer")->find($customer_one_id);

    my $customer_two_id = Test::XTracker::Data->create_test_customer(
        channel_id => $channel,
    );
    $self->{customer_two} = $self->rs("Public::Customer")->find($customer_two_id);

    #Get categories from DB
    $self->{categories} = $self->rs("Public::CustomerCategory")->search(
        {},
        {order_by => {-asc => "category"}}
    );

    #Get all channels from DB
    $self->{channels} = [$self->rs("Public::Channel")->channel_list->all];

    #Get the highest customer number for creation of invalid customers later on
    $self->{customer_max} = $self->rs("Public::Customer")->get_column('is_customer_number')->max;

    #Get the operator
    $self->{operator} = $self->rs("Public::Operator")->search( { username => 'it.god' } )->first;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::CustomerCare',
        ],
    );
    $self->{framework}->login_with_permissions( {
        roles => { names => [qw(
            app_canModifyCustomerCategory
        )] },
    } );

    $self->{jq}     = Test::XT::DC::JQ->new;

    # job queue worker
    $self->{jq_worker} = 'Receive::Customer::CustomerCategory';
}

sub setup : Test( setup => no_plan ) {
   my $self = shift;

    $self->{jq}->clear_ok;        # clear the job queue
}

sub teardown: Test( teardown => no_plan ) {
    my $self = shift;

    $self->{jq}->clear_ok;        # clear the job queue
}

=head2 test_each_customer_category

Test that a customer is able to be added to the job queue

Steps:
    1. Send a payload to the job queue where the customer category is the first category in the database
    2. Repeat this for each customer category in the database
    3. Check payload has gone onto job queue for each

=cut

sub test_each_customer_category : Tests() {
    my $self = shift;

    my $framework = $self->{framework};

    my @categories = $self->{categories}->all;

    #Go to customer category page and fill in form and submit
    #Do this for each category
    foreach my $category (@categories) {
        $framework->flow_mech__customercare__customercategory
                    ->flow_mech__customercare__customercategory__submit({
            channel   => $self->{channel},
            customers => $self->{customer_one}->is_customer_number,
            category  => $category->id,
        });

        $framework->{mech}->no_feedback_error_ok;

        #Expected payload
        my $payload = {
            customer_category_id    => $category->id,
            channel_id              => $self->{channel},
            customer_numbers        => [$self->{customer_one}->is_customer_number],
            operator_id             => $self->{operator}->id,
        };

        #check payload has gone onto job queue
        my $category_id = $self->{customer_one}->discard_changes->category_id;

        $self->{jq}->is_last_job
        ({
          funcname => 'XT::JQ::DC::Receive::Customer::CustomerCategory',
          payload  => $payload,
         }, 'last job is correct category update' );
        }
}

=head2 test_channel_list

Tests that the correct channels are shown in the drop down for each DC

    - DC1 should have NAP, MRP, OUT and JC
    - DC2 should have NAP, MRP, OUT and JC
    - DC3 should have NAP only

=cut

sub test_channel_list : Tests() {
    my $self = shift;

    my $framework = $self->{framework};

    #Go to bulk customer category page and check the drop down list containes correct channels
    $framework->flow_mech__customercare__customercategory;

    #Compare the drop down list with the enabled channels for each DC
    my @enabled_channels = @{$self->{channels}};
    my $pg_data = $framework->{mech}->as_data->{first_page};
    my $channel_string = join('', map {$_->name} @enabled_channels);
    like($pg_data->{Channel}{value}, qr/\Q...${channel_string}\E$/i, "Channels in dropdown as expected");
}

=head2 test_channels

Tests that a customer's category can be updated for each channel

Steps:
    1. Create a customer for each channel
    2. Update the customer category for the nap customer choosing nap as the channel
    3. Repeat this for each channel in the database

=cut

sub test_channels : Tests() {
    my $self = shift;
    my $framework = $self->{framework};

    my @channels = @{$self->{channels}};
    my @customers;

    #Create a customer for each channel
    foreach my $channel (@channels) {
        push @customers, Test::XTracker::Data->create_dbic_customer({
            channel_id  => $channel->id,
            category_id => $CUSTOMER_CATEGORY__NONE,
        });
    }

    #Go to bulk customer category page, fill in page and submit
    #Do this for each channel
    foreach my $customer (@customers) {
        $framework->flow_mech__customercare__customercategory
                    ->flow_mech__customercare__customercategory__submit({
            channel   => $customer->channel_id,
            customers => $customer->is_customer_number,
            category  => $CUSTOMER_CATEGORY__EIP,
        });

        $framework->{mech}->no_feedback_error_ok;

        #Expected payload
        my $payload = {
            customer_category_id    => $CUSTOMER_CATEGORY__EIP,
            channel_id              => $customer->channel_id,
            customer_numbers        => [$customer->is_customer_number],
            operator_id             => $self->{operator}->id,
        };

        #check payload has gone onto job queue
        my $category_id = $self->{customer_one}->discard_changes->category_id;

        $self->{jq}->is_last_job
        ({
          funcname => 'XT::JQ::DC::Receive::Customer::CustomerCategory',
          payload  => $payload,
         }, 'last job is correct category update' );
    }
}


=head2 test_multiple_valid_customers

Test that more than one customer can be updated at one time

    - Submit two valid customers
    - Valid customers should have the customer category updated
    - Valid customers should be listed in the success table

=cut

sub test_multiple_valid_customers : Tests() {
    my $self = shift;
    my $framework = $self->{framework};

    #Go to bulk customer category page
    $framework->flow_mech__customercare__customercategory;

    my $customer_list = join(",", $self->{customer_one}->is_customer_number, $self->{customer_two}->is_customer_number);

    #Submit form with two valid customer numbers
    $framework->flow_mech__customercare__customercategory__submit({
        channel     => $self->{channel},
        customers   => $customer_list,
        category    => $CUSTOMER_CATEGORY__EIP,
    });

    $framework->{mech}->no_feedback_error_ok;

        #Expected payload
        my $payload = {
            customer_category_id    => $CUSTOMER_CATEGORY__EIP,
            channel_id              => $self->{channel},
            customer_numbers        => [$self->{customer_one}->is_customer_number, $self->{customer_two}->is_customer_number],
            operator_id             => $self->{operator}->id,
        };

        #check payload has gone onto job queue
        my $category_id = $self->{customer_one}->discard_changes->category_id;

        $self->{jq}->is_last_job
        ({
          funcname => 'XT::JQ::DC::Receive::Customer::CustomerCategory',
          payload  => $payload,
         }, 'last job is correct category update' );

    #Check valid customers are in the success table
    my $pg_data = $framework->{mech}->as_data;
    my @valid_customer_list = (
        $pg_data->{success}[0]->{'Customer Number'},
        $pg_data->{success}[1]->{'Customer Number'}
    );

    cmp_deeply(\@valid_customer_list, bag($self->{customer_one}->is_customer_number, $self->{customer_two}->is_customer_number), "Valid customers on page as expected");
}

=head2 test_valid_and_invalid_customers

Tests one valid and one invalid customer together

    - Submit one valid and one invalid customer together
    - Valid customer should have the customer category updated and should be listed in success table
    - Invalid customer should not cause an error, but should be listed in the failed customers table

=cut

sub test_valid_and_invalid_customers : Tests() {
    my $self = shift;
    my $framework = $self->{framework};

    my $invalid_cust_number = $self->{customer_max} + 5;
    my $customer_list = join(",", $self->{customer_one}->is_customer_number, $invalid_cust_number);

    #Go to bulk update page
    $framework->flow_mech__customercare__customercategory;

    #Submit form with one valid customer and one invalid customer
    $framework->flow_mech__customercare__customercategory__submit({
        channel     => $self->{channel},
        customers   => $customer_list,
        category    => $CUSTOMER_CATEGORY__BOARD_MEMBER,
    });

    my $pg_data = $framework->{mech}->as_data;

    $framework->{mech}->no_feedback_error_ok;

    my $customer_one_cat = $self->{customer_one}->discard_changes->category_id;
    my $valid_customer_number = $pg_data->{success}[0]->{'Customer Number'};
    cmp_ok($valid_customer_number, "==", $self->{customer_one}->is_customer_number, "Valid customer on page as expected");

    #Test the invalid customer doesn't work
    my $invalid_customer = $pg_data->{failure}[0]->{'Failed Numbers'};
    cmp_ok($invalid_customer, "==", $invalid_cust_number, "Invalid customer as expected");

    #Expected payload
    my $payload = {
        customer_category_id    => $CUSTOMER_CATEGORY__BOARD_MEMBER,
        channel_id              => $self->{channel},
        customer_numbers        => [$self->{customer_one}->is_customer_number],
        operator_id             => $self->{operator}->id,
    };

    #check payload has gone onto job queue
    my $category_id = $self->{customer_one}->discard_changes->category_id;

    $self->{jq}->is_last_job
    ({
      funcname => 'XT::JQ::DC::Receive::Customer::CustomerCategory',
      payload  => $payload,
     }, 'last job is correct category update' );
}



=head2 test_invalid_customers_only

Test only invalid customers

    - Submit two invalid customers together
    - Invalid customers should not cause an error, but should be listed in the failed customers table
    - Tests the retry button
        - On click of retry, the numbers in the failure table should be copied into the customer numbers field on the first page

=cut

sub test_invalid_customers_only : Tests() {
    my $self = shift;
    my $framework = $self->{framework};

    my $invalid_customer_one = $self->{customer_max} + 6;
    my $invalid_customer_two = $self->{customer_max} + 7;

    my $customer_list = join(", ", $invalid_customer_one, $invalid_customer_two);

    #Go to bulk update page
    $framework->flow_mech__customercare__customercategory;

    #Submit form with two invalid customers
    $framework->flow_mech__customercare__customercategory__submit({
        channel     => $self->{channel},
        customers   => $customer_list,
        category    => $CUSTOMER_CATEGORY__HOT_CONTACT,
    });

    my $pg_data = $framework->{mech}->as_data;
    $framework->{mech}->no_feedback_error_ok;
    my @invalid_customer_list  = (
        $pg_data->{failure}[0]->{'Failed Numbers'},
        $pg_data->{failure}[1]->{'Failed Numbers'},
    );

    cmp_deeply(\@invalid_customer_list, bag( $invalid_customer_one, $invalid_customer_two), "Invalid customers on page as expected");

    $framework->flow_mech__customercare__customercategory__retry;
    $pg_data = $framework->{mech}->as_data;
    my $invalid_list = $pg_data->{retry_customer_list};
    cmp_ok($invalid_list, "eq", $customer_list, "Retry button worked");
}

=head2 test_acl_protection

Test the ACL protection on the /CustomerCare/CustomerCategory page

Steps:
    1. Accessing the page without any roles assigned should fail
    2. Accessing the page with roles that do not have permission to view the page should fail
    3. Accessing the page after assinging the required roles should succeed

=cut

sub test_acl_protection : Tests() {
    my $self = shift;

    my $framework = $self->{framework};

    note 'Logging in with no roles or department..';

    $framework->login_with_permissions( {
        roles => { },
        #make sure department is undef as we need to have no department selected
        dept => undef,
    } );

    note 'Accessing the /CustomerCare/CustomerCategory page with no roles should fail..';

    $framework->catch_error(
        qr/don't have permission to/i,
        q{Can't access the /CustomerCare/CustomerCategory page},
        flow_mech__customercare__customercategory => ()
    );

    note 'Setting roles that do not have permission to view the page..';

    $framework->{mech}->set_session_roles( '/Finance/PendingInvoices' );

    note 'Accessing the /CustomerCare/CustomerCategory page with invalid roles..';

    $framework->catch_error(
        qr/don't have permission to/i,
        q{Can't access the /CustomerCare/CustomerCategory page},
        flow_mech__customercare__customercategory => ()
    );

    note 'Setting valid roles for the session..';

    $framework->{mech}->set_session_roles( '/CustomerCare/CustomerCategory' );

    note 'Now accessing the page should succeed..';

    $framework->flow_mech__customercare__customercategory;
    $framework->{mech}->no_feedback_error_ok;

}

Test::Class->runtests;
