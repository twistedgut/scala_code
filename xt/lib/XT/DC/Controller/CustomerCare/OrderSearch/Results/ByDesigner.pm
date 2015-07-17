package XT::DC::Controller::CustomerCare::OrderSearch::Results::ByDesigner;

use NAP::policy     qw( class );

BEGIN { extends 'NAP::Catalyst::Controller::REST'; }

__PACKAGE__->config( path => 'CustomerCare/OrderSearchbyDesigner', );


use XTracker::Database::Utilities       qw( is_valid_database_id );

use XTracker::Logfile                   qw( xt_logger );


=head1 NAME

XT::DC::Controller::CustomerCare::OrderSearch::Results::ByDesigner - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller for the REST API part of the 'Customer Care->Order Search by Designer'
functionality.

=head1 METHODS

=head2 results_list

Controller for '/CustomerCare/OrderSearchbyDesigner/Results/[RESULT_FILE_NAME]/list'
this chains off from the 'results' Controller which can be found in the other
module 'XT::DC::Controller::CustomerCare::OrderSearch::ByDesigner'.

=cut

sub results_list :Chained('/customercare/ordersearch/bydesigner/results') PathPart('list') Args(0) ActionClass('REST') { }

=head2 results_list_GET

This will return a given page of the Search results in a JSON string. Use
the Query String parameters 'page' & 'number_of_rows' in the call to the
URL to control which page to get and how many rows to return:

    .../Results/[RESULT_FILE_NAME]/list?page=5&number_of_rows=50

Returns the following structure in a JSON string:

    {
        data => [
            # array of rows containing the results
            { col_name1 => 'value', ... },
            ...
        ],
        meta => {
            total_records => 500,
            # these contain the URLs to use to get to the next or previous page,
            # they will be empty if there is no next of previous page to get
            next_page_url => '.../[RESULT_FILE_NAME]/list?page=6&number_of_rows=50',
            prev_page_url => '.../[RESULT_FILE_NAME]/list?page=4&number_of_rows=50',
        },
    }

=cut

sub results_list_GET {
    my ( $self, $c ) = @_;

    my $result_file = $c->stash->{'result_file'} . '.txt';
    my $operator_rs = $c->stash->{'operator_rs'};

    if ( my $file_contents = $operator_rs->read_search_orders_by_designer_result_file( $result_file ) ) {
        my $page           = $c->request->param('page') || 1;
        my $number_of_rows = $c->request->param('number_of_rows') || 50;
        my $total_rows     = scalar( @{ $file_contents } );

        # work out the Total number of Pages
        my $total_pages = int( $total_rows / $number_of_rows );
        $total_pages++  if ( $total_rows % $number_of_rows );

        # work out the URLs of the next & prev pages
        my $next_url;
        my $prev_url;
        $next_url = $c->uri_for( $c->action, $c->req->captures, { page => ( $page + 1 ), number_of_rows => $number_of_rows } )
                                if ( $page < $total_pages );
        $prev_url = $c->uri_for( $c->action, $c->req->captures, { page => ( $page - 1 ), number_of_rows => $number_of_rows } )
                                if ( $page > 1 );

        my $results = $operator_rs->process_search_orders_by_designer_result_file_contents_for_json(
            $file_contents,
            {
                page           => $page,
                number_of_rows => $number_of_rows,
            },
        );
        $self->status_ok( $c,
            entity => {
                data => $results,
                meta => {
                    total_records => $total_rows,
                    next_page_url => $next_url || '',
                    prev_page_url => $prev_url || '',
                },
            }
        );
    }
    else {
        $self->status_not_found( $c, message => "Couldn't find any Results for file: ${result_file}" );
    }
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
