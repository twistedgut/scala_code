#!/usr/bin/env perl

use NAP::policy     qw( test );

use parent 'NAP::Test::Class';

=head1 NAME

Test Receive::Search::OrdersByDesigner job

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Designer;
use Test::XTracker::Data::SearchOrderByDesigner;
use Test::XT::Data;

use XTracker::Config::Local             qw( order_search_by_designer_result_file_path );
use XTracker::Constants                 qw( :application );

use Test::MockObject;
use Mock::Quick;


sub startup : Test( startup => no_plan ) {
    my $self = shift;

    Test::XTracker::Data::SearchOrderByDesigner->purge_search_result_dir();

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{worker} = 'Receive::Search::OrdersByDesigner';

    use_ok( 'XT::JQ::DC::' . $self->{worker} );

    $self->{designer_rs} = $self->rs('Public::Designer')->search(
        {
            id => { '!=' => 0 },
        }
    );

    $self->{operator} = $self->rs('Public::Operator')->search(
        {
            id       => { '!='        => $APPLICATION_OPERATOR_ID },
            username => { 'NOT ILIKE' => 'it.god' },
        }
    )->first;
}

sub teardown : Tests( teardown => no_plan ) {
    my $self = shift;

    $self->schema->txn_rollback();

    Test::XTracker::Data::SearchOrderByDesigner->purge_search_result_dir();
}


sub setup: Test( setup => no_plan ) {
    my $self = shift;

    $self->schema->txn_begin;

    $self->{data}   = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::Order',
        ],
    );

    $self->{designer_rs}->reset;
}


=head1 TESTS

=head2 test_job_request

Simply Test the Job can be created succesfully.

=cut

sub test_job_request : Tests {
    my $self = shift;

    my $payload = {
        results_file_name => 'MADE_UP_FILE_NAME.txt',
    };

    lives_ok {
        $self->_send_job( $payload, $self->{worker} );
    } "Fake job Send Order Search By Designer";
}

=head2 test_search_for_orders

Test that the correct Orders/Shipments are found by the Job Queue
Worker when it processes a Job and that the expected Search Result
files are created.

=cut

sub test_search_for_orders : Tests {
    my $self = shift;

    # this will get populated when 'send_email' is called
    my %email_contents;

    # where the Search Result files are created
    my $results_path = order_search_by_designer_result_file_path();


    # takeover 'XTracker::EmailFunctions' so
    # the 'send_email' function can be mocked
    my $email = qtakeover( 'XTracker::EmailFunctions' => () );
    $email->override(
        send_email => sub {
            my ( $from, $replyto, $to, $subject, $msg, $type, $attachments, $email_args ) = @_;
            note "---------------------------- IN REDEFINED 'send_email' function ----------------------------";
            %email_contents = (
                to          => $to,
                subject     => $subject,
                from        => $from,
                replyto     => $replyto,
                body        => $msg,
                type        => $type,
                attachments => $attachments,
                email_args  => $email_args,
            );
            return 1;
        },
    );

    my $channel  = Test::XTracker::Data->channel_for_nap();
    my $operator = $self->{operator};

    my ( $designer, $alt_designer ) = Test::XTracker::Data::Designer->grab_designers( {
        how_many       => 2,
        want_dbic_recs => 1,
        force_create   => 1,
    } );

    # create some Orders to search for
    my $number_of_orders = 5;
    my @orders = Test::XTracker::Data::Designer->create_orders_with_products_for_the_same_designer( $number_of_orders, {
        designer => $designer,
        channel  => $channel,
    } );


    note "TESTING - with a Designer that has Orders";

    # create the Pending File Name
    my $file_name = $self->_create_pending_results_file( $operator, $designer, $channel );

    # send & process the Job
    my $payload = {
        results_file_name => $file_name,
    };
    lives_ok {
        $self->_send_job( $payload, $self->{worker} );
    } "Fake job Send Order Search By Designer";

    # check the 'Pending' Search Results file is no longer present
    ok( !-f "${results_path}/${file_name}", "'Pending' Search Results file '${file_name}' has been removed" );

    # check that the 'Completed' Search Results file is present
    $file_name = $self->_check_for_completed_results_file( $operator, $designer, $channel, $number_of_orders );
    my $rows = Test::XTracker::Data::SearchOrderByDesigner->read_search_results_file( $file_name );

    my @expected = map { { shipment_id => $_->get_standard_class_shipment->id } } @orders;
    cmp_deeply( $rows, superbagof( @expected ), "Got Expected Shipment Ids in File" )
                        or diag "ERROR - Didn't get Expected Shipment Ids in File: " . p( $rows ) . "\n" . p( @expected );

    ok( scalar( keys %email_contents ), "An Email was sent" );
    # loose the extension on the file-name then check it's in the email
    $file_name =~ s/\.txt//;
    like( $email_contents{subject}, qr/${number_of_orders} records/, "Email Subject mentions the expected number of Records in it" );
    like( $email_contents{body}, qr[${file_name}/summary]s, "Email Body has the correct File Name link in it" );


    note "TESTING - with a Designer that has NO Orders for them";
    $number_of_orders = 0;

    $file_name = $self->_create_pending_results_file( $operator, $alt_designer, $channel );

    # clear out previous email details
    %email_contents = ();

    # send & process the Job
    $payload = {
        results_file_name => $file_name,
    };
    lives_ok {
        $self->_send_job( $payload, $self->{worker} );
    } "Fake job Send Order Search By Designer";

    # check the 'Pending' Search Results file is no longer present
    ok( !-f "${results_path}/${file_name}", "'Pending' Search Results file '${file_name}' has been removed" );

    # check that the 'Completed' Search Results file is present
    $file_name = $self->_check_for_completed_results_file( $operator, $alt_designer, $channel, $number_of_orders );
    $rows = Test::XTracker::Data::SearchOrderByDesigner->read_search_results_file( $file_name );
    ok( !scalar( @{ $rows } ), "Didn't find any Rows in the Completed Results file" )
                    or diag "ERROR - found Rows in the Completed Results file: " . p( $rows );

    ok( scalar( keys %email_contents ), "An Email was sent" );
    # loose the extension on the file-name then check it's in the email
    $file_name =~ s/\.txt//;
    like( $email_contents{subject}, qr/${number_of_orders} records/, "Email Subject has ZERO number of Records in it" );
    like( $email_contents{body}, qr[${file_name}/summary]s, "Email Body has the correct File Name link in it" );


    # stop mocking the 'send_email' function
    $email->restore('send_email');
}

#--------------------------------------------------------------

# helper to create a 'Pending' results file
sub _create_pending_results_file {
    my ( $self, $operator, $designer, $channel ) = @_;

    return Test::XTracker::Data::SearchOrderByDesigner->create_search_result_file( {
        designer => $designer,
        channel  => $channel,
        operator => $operator,
        state    => 'pending',
    } );
}

# helper to check for a 'Completed' results file
sub _check_for_completed_results_file {
    my ( $self, $operator, $designer, $channel, $number_of_orders ) = @_;

    my $file_name = Test::XTracker::Data::SearchOrderByDesigner->check_if_search_result_file_exists_for_search_criteria( {
        operator => $operator,
        designer => $designer,
        channel  => $channel,
        state    => 'completed',
        number_of_records => $number_of_orders,
    } );
    ok( $file_name, "Found a 'Completed' Search Results File: '${file_name}'" );

    return $file_name;
}

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

Test::Class->runtests;
