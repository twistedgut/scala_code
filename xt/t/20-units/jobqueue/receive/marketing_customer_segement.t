#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use parent 'NAP::Test::Class';
#
# Test Receive::NAPEvents::CustomerSegment job
#

use Test::XTracker::Data;
use Test::XT::Data;
use Test::XTracker::RunCondition export => ['$distribution_centre'];

use XTracker::Config::Local             qw( config_var );
use XTracker::Constants                 qw( :application );
use Test::MockObject;

my ($schema);
my $job_payload;
my $data;

sub startup : Test(startup => 1) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{data}   = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::MarketingCustomerSegment',
        ],
    );

    no warnings 'redefine';
    use_ok("XT::JQ::DC::Receive::NAPEvents::CustomerSegment");

    # re-define the 'set_payload' method so that we can get what payload is being sent
    use_ok("XT::JQ::DC");
    *XT::JQ::DC::set_payload    = sub {
                            my ( $self, $payload )  = @_;
                            $self->{job_payload}    = $payload;     # store it externally
                            return $self->{payload} = $payload;
                        };
    $self->{channel}  = $self->{data}->channel;
    $self->{customer} = $self->{data}->customer;


}

sub teardown : Tests(teardown => 0) {
    my $self = shift;

    $self->{segment}->marketing_customer_segment_logs->delete;
    $self->{segment}->link_marketing_customer_segment__customers->delete;
    $self->{segment}->link_marketing_promotion__customer_segments->delete;

    $self->schema->txn_rollback();
}


sub setup: Test(setup => 0) {
    my $self = shift;
    $self->{segment}  = $self->{data}->customer_segment;
    $self->{payload} = {};

    $self->schema->txn_begin;

}

# For some reason the test was originally written with
# $APPLICATION_OPERATOR_ID, who doesn't have an email
sub operator_with_email {
    my $self = shift;
    my $operator = $self->{schema}->resultset('Public::Operator')->search(
        { email_address => { q{!=} => undef }, },
        { rows => 1 },
    )->single;
    croak "Couldn't find operator with an email address" unless ($operator);
    return $operator;

}

sub test_job_request : Tests {
    my $self = shift;

    $self->{payload} = {
        customer_segment_id => 1,
        customer_list      => [1-23, 3_4, 5-6],
        current_user    => $self->operator_with_email->id,
    };

    $self->_set_operator_test_email();

    lives_ok( sub {
        $self->_send_job( $self->{payload}, "Receive::NAPEvents::CustomerSegment" );
    }, "Fake job :Send Customer List Request" );
}


sub test_with_valid_customer : Tests {
    my $self = shift;

    $self->{payload} = {
        customer_segment_id => $self->{segment}->id,
        customer_list       => [ $self->{customer}->is_customer_number ],
        current_user        => $self->operator_with_email->id,
    };

    lives_ok( sub {
        $self->_send_job( $self->{payload}, "Receive::NAPEvents::CustomerSegment" );
    }, " Real job : Send Customer List Request");

    # check link_marketing_customer_segment__customer and marketing_customer_segment

    $self->{segment}->discard_changes();
    cmp_ok($self->{segment}->job_queue_flag, '==', 0, "job queue flag got updated corectly");
    my $link_rs = $self->{segment}->search_related('link_marketing_customer_segment__customers',{
        customer_id => $self->{customer}->id,
    });

    cmp_ok($link_rs->count,'==', 1, " Count is ok");

}
sub test_deletion_customer_list: Test {
    my $self = shift;

    #get two customer
    my $nap = Test::XTracker::Data->channel_for_business(name => 'nap');
    my @customers;
    push( @customers, $self->{customer});
    push( @customers , Test::XTracker::Data->create_dbic_customer( { channel_id => $nap->id } ) );
    push( @customers , Test::XTracker::Data->create_dbic_customer( { channel_id => $nap->id } ) );
    push( @customers , Test::XTracker::Data->create_dbic_customer( { channel_id => $nap->id } ) );

    my (@customer_list, @customer_nr);

    # Attach customers ids to cusomter segment
    foreach my $customer ( @customers) {
        $self->{segment}->create_related('link_marketing_customer_segment__customers',{
            customer_id => $customer->id,
        });
        push(@customer_list, $customer->id);
        push(@customer_nr, $customer->is_customer_number);

    }

    my @original_list = @customer_list;
    #check to makde sure 4 customers are attached
    my $link_rs = $self->{segment}->search_related('link_marketing_customer_segment__customers',{
        customer_id => { -in => \@customer_list}
    });

    cmp_ok($link_rs->count,'==', 4, " Attaching Customers : Count is ok");


    my @deletion_list = ( shift @customer_nr, shift @customer_nr);
    #create a jq request to delete two of 4 customers
    $self->{payload}    = {
        customer_segment_id => $self->{segment}->id,
        customer_list      => \@deletion_list,
        current_user    => $self->operator_with_email->id,
        action_name     =>'delete',
    };

   lives_ok( sub {
        $self->_send_job( $self->{payload}, "Receive::NAPEvents::CustomerSegment" );
    }, " Real job : Send Customer List Request");

    $self->{segment}->discard_changes();
    cmp_ok($self->{segment}->job_queue_flag, '==', 0, "job queue flag got updated corectly");
    $link_rs = $self->{segment}->search_related('link_marketing_customer_segment__customers',{
        customer_id => { -in => \@original_list}
    });

    cmp_ok($link_rs->count,'==', 2," Deletion of Customer :Count is ok");

    #check if the right ones got deleted
    $link_rs = $self->{segment}->search_related('link_marketing_customer_segment__customers',{
        customer_id => { -in => \@deletion_list,},
    });

    cmp_ok($link_rs->count,'==', 0," Deletion of Customer :Correct Customers got deleted");

    #test clear list
    $self->{payload}    = {
        customer_segment_id => $self->{segment}->id,
        customer_list      => [ ],
        current_user    => $self->operator_with_email->id,
        action_name     => 'delete_all',
    };

    lives_ok( sub {
        $self->_send_job( $self->{payload}, "Receive::NAPEvents::CustomerSegment" );
    }, " Real job : Send Customer List Request");

    $self->{segment}->discard_changes();
    cmp_ok($self->{segment}->job_queue_flag, '==', 0, "job queue flag got updated corectly");
    $link_rs = $self->{segment}->search_related('link_marketing_customer_segment__customers',{
        customer_id => { -in => \@original_list}
    });

    cmp_ok($link_rs->count,'==', 0," Clear ALL :Count is ok");





}
sub test_with_customer_list : Tests {

    my $self = shift;
    #get two customer one for nap other for outnet
    my $out = Test::XTracker::Data->channel_for_business(name => 'outnet');
    my $nap = Test::XTracker::Data->channel_for_business(name => 'nap');
    my $customer2   = Test::XTracker::Data->create_dbic_customer( { channel_id => $out->id } );
    my $customer3   = Test::XTracker::Data->create_dbic_customer( { channel_id => $nap->id } );

    $self->{payload}    = {
        customer_segment_id => $self->{segment}->id,
        customer_list      => [
            $self->{customer}->is_customer_number,
            $customer2->is_customer_number,
            $customer3->is_customer_number
        ],
        current_user    => $self->operator_with_email->id,
    };

    $self->_set_operator_test_email();

    lives_ok( sub {
        $self->_send_job( $self->{payload}, "Receive::NAPEvents::CustomerSegment" );
    }, " Real job : Send Customer List Request");

    $self->{segment}->discard_changes();
    cmp_ok($self->{segment}->job_queue_flag, '==', 0, "job queue flag got updated corectly");
    my $link_rs = $self->{segment}->search_related('link_marketing_customer_segment__customers',{
        customer_id => { -in => [
            $self->{customer}->id,
            $customer2->id,
            $customer3->id
        ]}
    });

    cmp_ok($link_rs->count,'==', 2, " Attaching Customers : Count is ok");


    #Also test Deletion of customers
    $self->{payload}    = {
        customer_segment_id => $self->{segment}->id,
        customer_list      => [
            $customer3->is_customer_number
        ],
        current_user    => $self->operator_with_email->id,
        action_name     =>'delete',
    };

   lives_ok( sub {
        $self->_send_job( $self->{payload}, "Receive::NAPEvents::CustomerSegment" );
    }, " Real job : Send Customer List Request");

    $self->{segment}->discard_changes();
    cmp_ok($self->{segment}->job_queue_flag, '==', 0, "job queue flag got updated corectly");
    $link_rs = $self->{segment}->search_related('link_marketing_customer_segment__customers',{
        customer_id => { -in => [
            $self->{customer}->id,
            $customer3->id
        ]}
    });

    cmp_ok($link_rs->count,'==', 1," Deletion of Customer :Count is ok");
}

#--------------------------------------------------------------

# Creates and executes a job
sub _send_job {
    my $self = shift;
    my $payload = shift;
    my $worker  = shift;

    note "Job Payload: " . p( $payload );

    my $fake_job    = _setup_fake_job();
    my $funcname    = 'XT::JQ::DC::' . $worker;
    my $job         = new_ok( $funcname => [ payload => $payload, schema => $self->{schema}, dbh => $self->{schema}->storage->dbh, ] );
    my $errstr      = $job->check_job_payload($fake_job);
    die $errstr         if $errstr;
    $job->do_the_task( $fake_job );

    return $job;
}


# setup a fake TheShwartz::Job
sub _setup_fake_job {
    my $fake = Test::MockObject->new();
    $fake->set_isa('TheSchwartz::Job');
    $fake->set_always( completed => 1 );
    return $fake;
}

sub _set_operator_test_email {
    my $self = shift;

    my $op_object = $self->schema->resultset('Public::Operator')->find($APPLICATION_OPERATOR_ID);
    $op_object->email_address('test@example.com');
    $op_object->update();
}

Test::Class->runtests;
