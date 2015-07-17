#!/usr/bin/env perl
use NAP::policy qw( test );

BEGIN { use parent 'NAP::Test::Class' }

=head1 NAME

customercare_ordersearch_bydesigner.t

=head1 DESCRIPTION

Test the XT::DC::Controller::CustomerCare::OrderSearch::ByDesigner class.

=cut

use JSON;

use HTTP::Request::Common;
use HTTP::Status            qw( :constants status_message );
use Mock::Quick;

use Catalyst::Test 'XT::DC';

use Test::XT::Data;
use Test::XTracker::Data::SearchOrderByDesigner;


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    # Fake the response from the ACL has_permission method, so we can test
    # the API with and without permissions.
    $self->{acl} = qtakeover( 'XT::AccessControls' );
    $self->{acl}->override( has_permission => sub { return $self->{has_permission} } );

    # enable IT God Operator
    my $operator = $self->rs('Public::Operator')->search( { 'LOWER(username)' => 'it.god' } )->first;
    $operator->update( { disabled => 0 } );

    # We need to fake the application session, so it thinks we're logged in.
    # We're not testing authentication, so this just returns static data.
    $self->{xtdc} = qtakeover( 'XT::DC' );
    $self->{xtdc}->override( session => sub {
        return {
            operator_id => $operator->id,
            user_id     => $operator->username,
            acl         => {
                operator_roles => [],
            }
        }
    } );

    # get rid of any existing Result files
    Test::XTracker::Data::SearchOrderByDesigner->purge_search_result_dir();
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->schema->txn_begin;

    $self->{data} = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::Order',
        ]
    } );

    # By default every test should run with permissions granted.
    $self->{has_permission} = 1;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->schema->txn_rollback;
}

sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown();

    # Explicitly destroy the control objects, so the mocked objects are restored.
    $self->{acl}  = undef;
    $self->{xtdc} = undef;
}


=head1 TESTS

=head2 test_can_GET_urls

Test that the following URLs

    /CustomerCare/OrderSearchbyDesigner
    /CustomerCare/OrderSearchbyDesigner/Results/RESULTS_FILE_NAME/summary

can be reached

=cut

sub test_can_GET_urls : Tests {
    my $self = shift;

    $self->get_request_ok( "/OrderSearchbyDesigner" );
    $self->get_request_ok( "/OrderSearchbyDesigner/Results/RESULTS_FILE_NAME/summary" );
}

=head2 test_can_GET_json_urls

Test that the following JSON URLs

    /CustomerCare/OrderSearchbyDesigner/Results/RESULTS_FILE_NAME/list

can be reached and return JSON properly.

=cut

sub test_can_GET_json_urls : Tests() {
    my $self = shift;

    my $file_name = Test::XTracker::Data::SearchOrderByDesigner
                        ->create_orders_with_products_for_the_same_designer_and_results_file( 1 );

    note "test when the file-name doesn't exist";
    $self->get_json_request_ok( "/OrderSearchbyDesigner/Results/RESULTS_FILE_NAME/list", HTTP_NOT_FOUND, 1 );

    note "test when the file-name does exist";
    $file_name =~ s/\.txt//g;       # get rid of the '.txt' extenstion
    my $got = $self->get_json_request_ok( "/OrderSearchbyDesigner/Results/${file_name}/list" );
}

=head2 test_pagination_for_json_url

Tests that the Pagination works when calling the JSON URL:

    /OrderSearchbyDesigner/Results/RESULTS_FILE_NAME/list

This tests that the correct set of Results is returned and the 'meta' data
has the correct details in regards to pagination.

=cut

sub test_pagination_for_json_url : Tests() {
    my $self = shift;

    my ( $orders, $file_name ) = Test::XTracker::Data::SearchOrderByDesigner
                                    ->create_orders_with_products_for_the_same_designer_and_results_file( 16 );
    # get rid of the '.txt' extenstion
    $file_name =~ s/\.txt//g;

    # get the Shipments for all of the Orders
    my @shipments = map {
        $_->get_standard_class_shipment()
    } @{ $orders };

    # the number of rows that are to be on each page
    my $number_of_rows = 5;

    my %tests = (
        "First Page" => {
            params => {
                page => 1,
                number_of_rows => $number_of_rows,
            },
            expect => {
                shipments     => [ @shipments[0..4] ],
                next_page_url => { page => 2, number_of_rows => $number_of_rows },
                prev_page_url => '',
            },
        },
        "Second Page" => {
            params => {
                page => 2,
                number_of_rows => $number_of_rows,
            },
            expect => {
                shipments     => [ @shipments[5..9] ],
                next_page_url => { page => 3, number_of_rows => $number_of_rows },
                prev_page_url => { page => 1, number_of_rows => $number_of_rows },
            },
        },
        "Third Page" => {
            params => {
                page => 3,
                number_of_rows => $number_of_rows,
            },
            expect => {
                shipments     => [ @shipments[10..14] ],
                next_page_url => { page => 4, number_of_rows => $number_of_rows },
                prev_page_url => { page => 2, number_of_rows => $number_of_rows },
            },
        },
        "Fourth Page" => {
            params => {
                page => 4,
                number_of_rows => $number_of_rows,
            },
            expect => {
                shipments     => [ $shipments[15] ],
                next_page_url => '',
                prev_page_url => { page => 3, number_of_rows => $number_of_rows },
            },
        },
    );

    # the base URL including the file-name for all requests
    my $base_url = "/OrderSearchbyDesigner/Results/${file_name}/list";

    foreach my $label ( keys %tests ) {
        note "TESTING: ${label}";
        my $test   = $tests{ $label };
        my $expect = $test->{expect};

        my $query_str = '';
        my $seperator = '';
        while ( my ( $param, $value ) = each %{ $test->{params} } ) {
            $query_str .= $seperator . "${param}=${value}";
            $seperator  = '&';
        }

        # make the request
        my $got  = $self->get_json_request_ok( "${base_url}?${query_str}" );
        my $data = $got->{data};
        my $meta = $got->{meta};

        # check the pagination
        $self->_check_pagination_url( 'next_page_url', $base_url, $meta, $expect );
        $self->_check_pagination_url( 'prev_page_url', $base_url, $meta, $expect );

        # check the records that were returned
        my $shipments = $expect->{shipments};
        cmp_ok( scalar( @{ $data } ), '==', scalar( @{ $shipments } ),
                                "got the expected number of Shipments in the 'data' returned" );
        cmp_deeply(
            [ map { $_->{shipment_id} } @{ $data }      ],
            [ map { $_->id            } @{ $shipments } ],
            "and got the correct Shipment Ids and in the correct sequence"
        );
    }
}


=head1 METHODS

=head2 get_request_ok

Helper method to make GET requests.

=cut

sub get_request_ok {
    my $self = shift;
    my ( $url, $expected_code, $expect_error, $args ) = @_;

    $url             = "/CustomerCare${url}",
    $expected_code //= HTTP_OK;
    $expect_error  //= 0;

    my $content_type = $args->{content_type} || 'text/html';

    my $expected_code_str = "${expected_code} - " . ( status_message( $expected_code ) // 'unknown HTTP code' );

    my $response = request
        GET $url,
        'Content-Type' => $content_type,
    ;

    cmp_ok( $response->code,
        '==',
        $expected_code,
        "HTTP response code is '$expected_code_str' as expected" );

    $expect_error
        ? ok( $response->is_error, "Request to '$url' returns an error" )
        : ok( $response->is_success, "Request to '$url' returns a success" );

    return $response->content;
}

=head2 get_json_request_ok

Wraps around 'get_request_ok' but sets the content type to 'application/json'
and checks that any response is valid JSON.

=cut

sub get_json_request_ok {
    my ( $self, $url, @params ) = @_;

    my $content = $self->get_request_ok( $url, $params[0], $params[1], {
        content_type => 'application/json'
    } );

    my $result;
    try {
        $result = decode_json( $content );
        pass( "Response content decoded as JSON for '$url'" );
    } catch {
        fail( "Response content NOT valid JSON for '$url'" );
    };

    return $result;
}


# helper to check the pagination URLs data returned in the request
sub _check_pagination_url {
    my ( $self, $url_type, $base_url, $got, $expect ) = @_;

    if ( my $param_parts = $expect->{ $url_type } ) {
        my $url = $got->{ $url_type };
        ok( $url, "Found '${url_type}' URL in meta-data" );
        like( $url, qr/${base_url}/,
                            "base URL as expected" );
        like( $url, qr/\?.*page=$param_parts->{page}/,
                            "'page' param in query string as expected" );
        like( $url, qr/\?.*number_of_rows=$param_parts->{number_of_rows}/,
                            "'number_of_rows' param in query string as expected" );
    }
    else {
        ok( !$got->{ $url_type }, "no '${url_type}' was found in the meta-data returned" )
                        or diag "ERROR - '${url_type}' was found in meta-data: " . p( $got->{ $url_type } );
    }

    return;
}


Test::Class->runtests;
