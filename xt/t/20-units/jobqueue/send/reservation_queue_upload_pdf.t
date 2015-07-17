#!/usr/bin/env perl

use NAP::policy "tt",     'test';

use Test::MockObject;
use DateTime;

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => qw( $distribution_centre );

use XTracker::Constants                 qw( :application );
use XTracker::Database::Reservation     qw( queue_upload_pdf_generation );
use XTracker::Utilities                 qw( :string );
use XTracker::Config::Local             qw( config_var );

use_ok("XT::JQ::DC::Receive::StockControl::Reservation::PreparePDF");


my $schema      = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'sanity test' );

#--------------- Run TESTS ---------------
_test_queue_upload_pdf( $schema, 1 );
#--------------- END TESTS ---------------

done_testing;

#----------------------- Test Functions -----------------------

sub _test_queue_upload_pdf {
    my ( $schema, $oktodo )     = @_;

    SKIP: {
        skip "_test_queue_upload_pdf", 1        if ( !$oktodo );

        my $upload_date     = DateTime->now()->dmy('-');
        my $filename_base   = config_var('SystemPaths','include_dir') . '/';
        my $app_op_id       = $APPLICATION_OPERATOR_ID;
        my $jq_worker       = 'Receive::StockControl::Reservation::PreparePDF';

        my @channels    = $schema->resultset('Public::Channel')->all;
        foreach my $channel ( @channels ) {
            note "TEST: " . $channel->name;

            my $channel_name= $channel->name;
            my $channel_id  = $channel->id;

            # build up the basic data to send to the function
            my %data    = (
                    channels    => {
                            $channel->id    => {
                                    name    => $channel->name,
                                },
                        },
                    upload_date => {
                            $channel->name  => $upload_date,
                        },
                );
            # set what the Expected Payload should always contain
            my %expected_payload    = (
                        channel_name    => $channel_name,
                        channel_id      => $channel_id,
                        output_filename => $filename_base . "upload_${channel_id}_${upload_date}_${app_op_id}.pdf",
                        upload_date     => $upload_date,
                        current_user    => $app_op_id,
                );

            # set-up filters to be used in tests
            my %filter  = (
                    exclude_designer_ids    => [
                                        1234,
                                        3232,
                                        234,
                                    ],
                    exclude_pids    => [
                                        1231414,
                                        123123,
                                        4234243,
                                    ],
                );

            # tests for different Payloads
            my %tests   = (
                    'No Filter for Request' => {
                            data_in         => \%data,
                            expected_payload=> \%expected_payload,
                        },
                    'Filter On Designers Only' => {
                            data_in         => {
                                                %data,
                                                pdf_filter  => { exclude_designer_ids => $filter{exclude_designer_ids} },
                                            },
                            expected_payload=> {
                                                %expected_payload,
                                                filter  => { exclude_designer_ids => $filter{exclude_designer_ids} },
                                            },
                        },
                    'Filter On PIDs Only' => {
                            data_in         => {
                                                %data,
                                                pdf_filter  => { exclude_pids => $filter{exclude_pids} },
                                            },
                            expected_payload=> {
                                                %expected_payload,
                                                filter  => { exclude_pids => $filter{exclude_pids} },
                                            },
                        },
                    'Filter On both Designers & PIDs' => {
                            data_in         => {
                                                %data,
                                                pdf_filter  => {
                                                        exclude_designer_ids=> $filter{exclude_designer_ids},
                                                        exclude_pids        => $filter{exclude_pids},
                                                    },
                                            },
                            expected_payload=> {
                                                %expected_payload,
                                                filter  => {
                                                        exclude_designer_ids=> $filter{exclude_designer_ids},
                                                        exclude_pids        => $filter{exclude_pids},
                                                    },
                                            },
                        },
                );

            foreach my $label ( keys %tests ) {
                note "Testing: $label";
                my $test    = $tests{ $label };

                # used to capture what is sent to the Job
                my $job_request = {};

                my $handler = _setup_fake_handler( $test->{data_in}, $job_request );

                # queue the Job then inspect what was Passed
                my $message = queue_upload_pdf_generation( $handler, $channel->id, $channel->name );
                like( $message, qr/PDF for the $upload_date upload for $channel_name is being generated/i,
                                        "Got back Message saying 'PDF is being generated'" );
                is( $job_request->{funcname}, $jq_worker,
                                        "Expected Job Queue Function Passed In: ${jq_worker}" );
                is_deeply( $job_request->{payload}, $test->{expected_payload},
                                        "Job Payload as Expected" );

                # now check that the Payload can actually
                # be passed to the Job Queue Worker
                my $job;
                lives_ok { $job = _send_job( $job_request->{payload}, $jq_worker ); }
                                    "Payload Could actually be sent to the Job Queue Worker";
                isa_ok( $job, "XT::JQ::DC::${jq_worker}", "and Job is as Expected" );
            }
        }
    };

    return;
}


#--------------------------------------------------------------

# Creates and executes a job
sub _send_job {
    my $payload = shift;
    my $worker  = shift;

    my $fake_job    = _setup_fake_job();
    my $funcname    = 'XT::JQ::DC::' . $worker;
    my $job         = new_ok( $funcname => [ payload => $payload, schema => $schema, dbh => $schema->storage->dbh, ] );
    my $errstr      = $job->check_job_payload($fake_job);
    die $errstr     if $errstr;
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

# setup a fake XTracker::Handler
sub _setup_fake_handler {
    my ( $data, $return_from_method )   = @_;

    my $fake    = Test::MockObject->new( { data => $data } );
    $fake->set_isa('XTracker::Handler');
    $fake->set_always( operator_id => $APPLICATION_OPERATOR_ID );

    # mock the 'create_job' method so
    # the params can be captured
    $fake->mock( 'create_job', sub {
                        my ( $self, $funcname, $payload )   = @_;

                        $return_from_method->{funcname} = $funcname;
                        $return_from_method->{payload}  = $payload;

                        return 1;
                    }
                );

    return $fake;
}
