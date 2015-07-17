#!/usr/bin/env perl

use NAP::policy "tt", qw/test class/;

BEGIN {
    extends 'NAP::Test::Class';
};

=head1 NAME

t/20-units/scripts/customer/sendCustomerValue.pl

=head1 DESCRIPTION

=head2 CANDO-7913: Script to push Customer Values to Seaview(Bosh)

This tests the script and all command line parameters

=cut


use XTracker::Script::Customer::SendCustomerValueToSeaview;
use Test::XTracker::Data;
use File::Temp qw/tempfile/;
use File::Slurp qw/read_file/;


sub startup : Test(startup => no_plan) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema}  = Test::XTracker::Data->get_schema;
    $self->{channel} = Test::XTracker::Data->channel_for_nap;
}

sub setup : Test(setup => no_plan) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;
}

sub teardown : Test(teardown => no_plan) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
    $self->{script_obj} = undef;

}

sub test_option_all :Tests() {
    my $self = shift;

    note 'Test to check script pushes the customer values correctly';

    my ( $customer, $service_logs) = $self->_prepare_data;

    # Create 2 Customers
    my $customer1 = Test::XTracker::Data->create_dbic_customer( { channel_id => $self->{channel}->id } );
    my $customer2 = Test::XTracker::Data->create_dbic_customer( { channel_id => $self->{channel}->id } );

    # Instantitate script with "--all" option
    $self->_new_instance( { all => 1 } );
    my $obj = $self->script_obj;
    $obj->invoke();

    # Check Pushing to Seaview is logged.
    $service_logs = $self->schema->resultset('Public::CustomerServiceAttributeLog');
    cmp_ok($service_logs->count, '==', 2, "All options Works correctly");

}

sub test_command_line_args : Tests() {
    my $self = shift;

    note 'Test to check script pushes Command Line ARGS correctly';

    my ( $customer, $service_logs) = $self->_prepare_data;

    # Create 2 Customers
    my $customer1 = Test::XTracker::Data->create_dbic_customer( { channel_id => $self->{channel}->id } );
    my $customer2 = Test::XTracker::Data->create_test_customer(channel_id => $self->{channel}->id);

    my $customer2_rs = $customer->find($customer2);

    # Update account_urn of one of the customer
    $customer2_rs->update({account_urn => '_test_ARGV'} );

    # Instantitate script with "Command Line Arguments" option
    my @testing = ( '_test_ARGV');
    $self->_new_instance( { argv => \@testing } );
    my $obj = $self->script_obj;
    $obj->invoke();

    # Check log count
    $service_logs = $self->schema->resultset('Public::CustomerServiceAttributeLog');
    cmp_ok($service_logs->count, '==', 1, "Command Line Arguments were passed correctly");

}

sub test_stdin_option : Tests() {
    my $self = shift;

    note 'Test to check stdin is passed correctly';

    my ( $customer, $service_logs) = $self->_prepare_data;
    my $customer1 = Test::XTracker::Data->create_test_customer(channel_id => $self->{channel}->id);
    my $customer1_rs = $customer->find($customer1);

    # Update account_urn of one of the customer
    $customer1_rs->update({account_urn => '_test_stdin'});

    open my $fh, '<', \"_test_stdin 22 testing";
    local *STDIN = $fh;
    close($fh);

    $self->_new_instance( { stdin => 1 } );
    my $obj = $self->script_obj;
    $obj->invoke();

    $service_logs = $self->schema->resultset('Public::CustomerServiceAttributeLog');
    cmp_ok($service_logs->count, '==', 1, "'stdin' option  works correctly");
}


sub test_file_path_option : Tests() {
    my $self = shift;

    note 'Test to check script pushes Command Line ARGS correctly';

     my ( $customer, $service_logs) = $self->_prepare_data;

    my $customer_1 = Test::XTracker::Data->create_test_customer(channel_id => $self->{channel}->id);
    my $customer1_rs = $customer->find($customer_1);

    my $urn = $customer1_rs->account_urn;
    my @parameter_list =  ( 'failure_urn',$urn );

    open my $failure_fh, '>', \(my $failure_content);
    open my $success_fh, '>', \(my $success_content);

    $self->_new_instance( {
        failed_file_path    => $failure_fh,
        success_file_path   => $success_fh,
        argv                => \@parameter_list
    } );

    close($failure_fh);
    close($success_fh);
    my $obj = $self->script_obj;
    $obj->invoke;

    cmp_ok ( $failure_content, 'eq',"failure_urn\n", "Failed File content is correct");
    cmp_ok ( $success_content, 'eq' , "$urn\n", "Success File content is correct");

}


sub test_defaults : Tests() {
    my $self    = shift;

    my $obj = $self->script_obj;


    my %expected    = (
            verbose             => 0,
            dryrun              => 0,
            failed_file_path    => undef,
            success_file_path   => undef,
            all                 => 0,
            stdin               => 0,
            batch               => 1000,
        );
    my %got = map { $_ => $obj->$_ } keys %expected;

    is_deeply( \%got, \%expected, "Class has expected Defaults" );

    return;
}

sub test_overiding_defaults : Tests() {
    my $self    = shift;

    $self->_new_instance( { verbose => 1 } );
    cmp_ok( $self->script_obj->verbose, '==', 1, "'verbose' overidden" );

    $self->_new_instance( { dryrun => 1 } );
    cmp_ok( $self->script_obj->dryrun, '==', 1, "'dryrun' overidden" );

    $self->_new_instance( { all => 1 } );
    cmp_ok( $self->script_obj->all, '==', 1, "'all' overidden" );

    $self->_new_instance( { stdin => 1 } );
    cmp_ok( $self->script_obj->stdin, '==', 1, "'stdin' overidden" );

    $self->_new_instance( { batch => 200 } );
    cmp_ok( $self->script_obj->all, '==', 200, "'batch' overidden" );

    my ($fail_fh, $failed_filename) = tempfile();
    $self->_new_instance( { failed_file_path => $failed_filename } );
    if (defined fileno $fail_fh ) {
        pass("Failed file path overridden");
    } else {
        fail("Failed file path was not overridden");
    }

    my ($success_fh, $success_filename) = tempfile();
    $self->_new_instance( { success_file_path => $success_filename } );
    if (defined fileno $success_fh ) {
        pass("Success file path overridden");
    } else {
        fail("Success file path was not overridden");
    }

    return;
}

sub _new_instance {
    my ( $self, $options )  = @_;
    $self->{script_obj} = undef;

    $self->{script_obj} = XTracker::Script::Customer::SendCustomerValueToSeaview->new_with_options( $options || {} );

    # need to use our copy of Schema & DBH
    $self->{script_obj}->{schema}   = $self->schema;
    $self->{script_obj}->{dbh}      = $self->schema->storage->dbh;
    return;
}

sub script_obj {
    my $self    = shift;
    $self->_new_instance            if ( !$self->{script_obj} );
    return $self->{script_obj};
}

sub _prepare_data {
    my $self = shift;


    # Update all customer's account urn's to be undef
    my $customer = $self->schema->resultset('Public::Customer');
    $customer->update({account_urn => undef});

    # Delete all logs as well
    my $service_logs = $self->schema->resultset('Public::CustomerServiceAttributeLog');
    $service_logs->delete_all;

    return ( $customer, $service_logs);
}
