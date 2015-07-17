package XT::DC::Controller::CustomerCare::OrderSearch::ByDesigner;

use NAP::policy     qw( class );

BEGIN { extends 'Catalyst::Controller'; }

__PACKAGE__->config( path => 'CustomerCare/OrderSearchbyDesigner', );

use XTracker::Config::Local             qw( config_var order_search_by_designer_result_file_path );
use XTracker::Database::Utilities       qw( is_valid_database_id );
use XTracker::Logfile                   qw( xt_logger );

use XT::JQ::DC;

use IO::File;


=head1 NAME

XT::DC::Controller::CustomerCare::OrderSearch::ByDesigner - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for the 'Customer Care->Order Search by Designer' functionality.

=head1 METHODS

=head2 by_designer

Controller for '/CustomerCare/OrderSearchbyDesigner'

=cut

sub by_designer :Path :Args(0) ActionClass('REST') {
    my ( $self, $c ) = @_;

    $c->check_access( 'Customer Care', 'Order Search by Designer' );

    $c->stash(
        template => 'ordertracker/customercare/ordersearch/by_designer.tt',
    );
}

=head2 by_designer_GET

This will draw the intial Search page which also has a table
of previous Searches which can be clicked on to see the Orders.

=cut

sub by_designer_GET {
    my ( $self, $c ) = @_;

    my $schema = $c->model('DB');

    my $channel_list  = [
        $schema->resultset('Public::Channel')->enabled_channels->all
    ];
    my $designer_list = [
        grep {
            $_->id != 0
        } $schema->resultset('Public::Designer')->designer_list->all
    ];

    my $results_list = $schema->resultset('Public::Operator')
                                ->get_list_of_search_orders_by_designer_result_files_for_view();

    $c->stash(
        channel_list  => $channel_list,
        designer_list => $designer_list,
        results_list  => $results_list,
    );
    $self->_populate_stash_with_js_and_css( $c );
}

=head2 by_designer_POST

This will create a new Search Job on TheSchwartz Job Queue it will
then call 'by_designer_GET' to display the Search page again.

=cut

sub by_designer_POST {
    my ( $self, $c ) = @_;

    my $schema         = $c->model('DB');
    my $request_params = $c->request->parameters;
    my $param_errors   = 0;

    my $designer;
    my $designer_id = $request_params->{designer_id};
    if ( is_valid_database_id( $designer_id ) ) {
        $designer = $schema->resultset('Public::Designer')->find( $designer_id );
        unless ( $designer ) {
            $c->feedback_warn( "Unknown Designer: ${designer_id}" );
            $param_errors = 1;
        }
    }
    else {
        $c->feedback_warn( "Invalid or No Designer Id passed: '" . ( $designer_id // 'undef' ) . "'" );
        $param_errors = 1;
    }

    # if a Channel Id is passed in then check it's ok
    my $channel;
    if ( my $channel_id = $request_params->{channel_id} ) {
        if ( is_valid_database_id( $channel_id ) ) {
            $channel = $schema->resultset('Public::Channel')->find( $channel_id );
            unless ( $channel ) {
                $c->feedback_warn( "Unknown Channel: ${channel_id}" );
                $param_errors = 1;
            }
        }
        else {
            $c->feedback_warn( "Invalid Channel Id passed: '" . ( $channel_id // 'undef' ) . "'" );
            $param_errors = 1;
        }
    }

    # can't go any further if there is a problem with the params passed in
    $c->detach( $self, 'by_designer_GET' )      if ( $param_errors );


    # create an empty Search Results file for the Operator and Designer
    # and then create a Job Queue job that will actually do the search

    my $operator  = $c->model('ACL')->operator;
    my $file_path = order_search_by_designer_result_file_path();
    my $file_name = $operator->create_orders_search_by_designer_file_name( {
        state    => 'pending',
        designer => $designer,
        channel  => $channel,
    } );

    # create the empty file which will eventually be populated by the results
    # and act as part of the Search Results list that appears on the Search page
    my $no_errors = 1;
    try {
        my $full_file_name = "${file_path}/${file_name}";
        my $fh = IO::File->new( ">${full_file_name}" )
                    || die "Couldn't create file '${full_file_name}': " . $! . "\n";
        $fh->close();
    } catch {
        my $err = $_;
        $c->feedback_warn( "Couldn't create Search Results file: ${err}" );
        $no_errors = 0;
    };

    if ( $no_errors ) {
        # create the Job to actually do the Search
        my $job_rq = XT::JQ::DC->new( { funcname => 'Receive::Search::OrdersByDesigner' } );
        $job_rq->set_payload( {
            results_file_name => $file_name,
        } );
        my $job = $job_rq->send_job();
        $c->feedback_success( "Search Request Created for '" . $designer->designer . "', Job Queue Job Id: " . $job->jobid );
    }

    # re-direct back to the Search page, this avoids people re-freshing
    # the page and re-submitting the same request time and time again
    $c->response->redirect( $c->uri_for( $self->action_for('by_designer') ) );
}

=head2 results

Controller for '/CustomerCare/OrderSearchbyDesigner/Results/[RESULT_FILE_NAME]/' and Start of
the Chain for '../summary' & the REST API '../list' URLs.

[RESULT_FILE_NAME] - is the file name (without an extension) of a Completed Search Result file.

=cut

sub results :Chained('/') PathPart('CustomerCare/OrderSearchbyDesigner/Results') CaptureArgs(1) {
    my ( $self, $c, $result_file ) = @_;

    $c->check_access( 'Customer Care', 'Order Search by Designer' );

    my $operator_rs  = $c->model('DB::Public::Operator');
    # get the details of the Search Result file
    # to be used by other Controllers on the Chain
    my $file_details = $operator_rs->parse_orders_search_by_designer_file_name( $result_file . '.txt' );

    $c->stash(
        operator_rs  => $operator_rs,
        result_file  => $result_file,
        file_details => $file_details,
    );
}

=head2 results_summary

Controller for '/CustomerCare/OrderSearchbyDesigner/Results/[RESULT_FILE_NAME]/summary'

=cut

sub results_summary :Chained('results') PathPart('summary') Args(0) ActionClass('REST') { }

=head2 results_summary_GET

Gets the basic details of the Search Results file and draws the page where the
Results will be shown.

=cut

sub results_summary_GET {
    my ( $self, $c ) = @_;

    $c->stash(
        fullwidthcontent => 1,
        template         => 'ordertracker/customercare/ordersearch/by_designer_results.tt',
    );
    $self->_populate_stash_with_js_and_css( $c );
}


# helper to set the 'stash' up with the
# correct JS and CSS links for these pages
sub _populate_stash_with_js_and_css {
    my ( $self, $c ) = @_;

    return $c->stash(
        css => [
            config_var( 'UI_Styles', 'jtable_theme_path' ),
        ],
        js => [
            config_var( 'UI_Styles', 'jtable_js_path' ),
            '/javascript/jquery/plugin/nap/utilities.js',
            '/javascript/customercare/order_search_by_designer.js',
        ],
    );
}

=encoding utf8

=head1 AUTHOR

Andrew Beech

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
