package XT::JQ::DC::Receive::Search::OrdersByDesigner;

use NAP::policy     qw( class );

use MooseX::Types::Moose        qw( Str Int Maybe ArrayRef );
use MooseX::Types::Structured   qw( Dict Optional );

use XTracker::Logfile           qw( xt_logger );
use XTracker::Config::Local     qw( config_var order_search_by_designer_result_file_path );

use Benchmark       qw( :hireswallclock );

use namespace::clean -except => 'meta';

use XTracker::EmailFunctions    qw( send_internal_email );


extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    isa => Dict[
        results_file_name => Str,
    ],
    required => 1,
);

has logger => (
    is => 'rw',
    default => sub { return xt_logger('XT::JQ::DC'); }
);


sub do_the_task {
    my ($self, $job) = @_;

    my $error = "";

    my $schema      = $self->schema;
    my $operator_rs = $schema->resultset('Public::Operator');

    # these will get populated if the search runs without errors
    my $operator;
    my $result_details;

    my $benchmark_log = xt_logger('Benchmark');

    try {
        my $result_file_path = order_search_by_designer_result_file_path();
        my $file_name        = $self->payload->{results_file_name};
        my $full_file_name   = "${result_file_path}/${file_name}";

        if ( -r $full_file_name ) {
            my $parsed_file_name = $operator_rs->parse_orders_search_by_designer_file_name( $file_name );
            if ( $self->_check_parsed_details_ok( $parsed_file_name, $file_name ) ) {
                $operator    = $parsed_file_name->{operator};
                my $designer = $parsed_file_name->{designer};
                my $channel  = $parsed_file_name->{channel};

                # remove the 'Pending' Search Results file
                unlink( $full_file_name )
                            or $self->logger->warn( "Couldn't remove 'Pending' Search Results file: '${full_file_name}'" );

                # get the start time for Benchmarking
                my $start_time = Benchmark->new;

                # run the Search
                $result_details = $operator->create_completed_orders_search_by_designer_results_file(
                    $designer,
                    $channel,
                );

                # log how long it took
                my $end_time = Benchmark->new;
                $benchmark_log->info(
                    "Order Search By Designer '" . $designer->designer . "' " .
                    "for Channel '" . ( $channel ? $channel->name : 'ANY' ) . "', " .
                    "Completed File: '" . $result_details->{file_name} . "', " .
                    "Total Time = " . timestr( timediff( $end_time, $start_time ), 'all' )
                );

                # add to the Result Details so that they
                # can be used in the Operator email
                $result_details->{designer} = $designer;
                $result_details->{channel}  = $channel;
            }
        }
        else {
            $self->logger->error( "Couldn't Find File or File not Readable: '${full_file_name}'" );
            $error = 1;
        }
    }
    catch {
        $error = $_;
        $self->logger->error( qq{Failed job with error: $error} );
        $job->failed( $error );
    };

    unless ( $error ) {
        # send the Operator an Email that the Search has Completed
        # but there is no need to fail the Job if this bit fails
        try {
            $self->_send_operator_email( $operator, $result_details );
        } catch {
            my $error = $_;
            $self->logger->warn( "Couldn't Send Email to Operator '(" . $operator->id . ") " . $operator->name . "': ${error}" );
        }
    }

    return;
}

sub check_job_payload {
    my ($self, $job) = @_;
    return ();
}


# send an Internal Email to the Operator
# telling them the Search has finished
sub _send_operator_email {
    my ( $self, $operator, $result_details ) = @_;

    my $designer = $result_details->{designer};
    my $channel  = $result_details->{channel};

    my $subject = "Search Orders By Designer '" . $designer->designer . "' " .
                  "for Channel '" . ( $channel ? $channel->name : 'ANY' ) . "' " .
                  "has Completed and found " . $result_details->{number_of_records} . " records"
    ;


    # make up the link to the results file in xTracker
    my $file_name = $result_details->{file_name};
    $file_name    =~ s/\.txt//;
    my $link = 'http://' . config_var( 'URL', 'url' ) .
               '/CustomerCare/OrderSearchbyDesigner/Results/' .
               $file_name . '/summary'
    ;

    return send_internal_email(
        to      => $operator->email_address,
        subject => $subject,
        from_file => {
            path => 'email/internal/order_search_by_designer_results.tt',
        },
        stash => {
            %{ $result_details },
            operator        => $operator,
            link_to_results => $link,
            dc              => config_var( 'DistributionCentre', 'name' ),
            template_type   => 'email',
        },
    );
}

# check that the details that are got from the File Name are
# correct such as the Designer & Operator exist
sub _check_parsed_details_ok {
    my ( $self, $parsed_details, $file_name ) = @_;

    my $err_msg_suffix = "File Name: '${file_name}'";
    if ( !$parsed_details ) {
        $self->logger->error( "Couldn't Parse ${err_msg_suffix}" );
        # no point in continuing so return FALSE now
        return 0;
    }

    my $retval = 1;

    if ( !$parsed_details->{designer} ) {
        $self->logger->error( "Couldn't find Designer for ${err_msg_suffix}" );
        $retval = 0;
    }

    if ( !$parsed_details->{operator} ) {
        $self->logger->error( "Couldn't find Operator for ${err_msg_suffix}" );
        $retval = 0;
    }

    return $retval;
}


1;

__END__

=head1 NAME

XT::JQ::DC::Receive::Search::OrdersByDesigner - Job Queue Worker

=head1 DESCRIPTION

This worker will actually do the Search to find Orders for a particulat Designer,
it will be passed a 'Pending' Order Search by Designer Results file name which can
be parsed to find out which Designer and Sales Channel (if any) to search against.

Expected Payload should look like:

    {
        results_file_name => '12_23_1_20150102123456_PENDING.txt',
    }

=cut

