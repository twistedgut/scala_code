#!/usr/bin/env perl
use NAP::policy qw( tt test );

BEGIN { use parent 'NAP::Test::Class' }

=head1 NAME

Test::XT::DC::Controller::API::Customer

=head1 DESCRIPTION

Test the XT::DC::Controller::API::Customer class.

=cut

use JSON;
use HTTP::Request::Common;
use HTTP::Status            qw( :constants status_message );
use Mock::Quick;

use Catalyst::Test 'XT::DC';

use Test::XT::Data;


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    use_ok 'XT::DC::Controller::API::Payment';

    # Fake the response from the ACL has_permission method, so we can test
    # the API with and without permissions.
    $self->{acl} = qtakeover( 'XT::AccessControls' );
    $self->{acl}->override( has_permission => sub { return $self->{has_permission} } );

    # We need to fake the application session, so it thinks we're logged in.
    # We're not testing authentication, so this just returns static data.
    $self->{xtdc} = qtakeover( 'XT::DC' );
    $self->{xtdc}->override( session => sub { return { operator_id => 1, user_id => 'it.god' } } );
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

sub shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown();

    # Explicitly destroy the control objects, so the mocked objects are restored.
    $self->{acl}  = undef;
    $self->{xtdc} = undef;
}


=head1 TESTS

=head2 test__GET_invalid_customer__address_list

Test that Invalid Requests to the API:

    /api/customer/[customerId]/address_list

returns the expected HTTP Error codes.

=cut

sub test__GET_invalid_customer__address_list : Tests {
    my $self = shift;

    my $max_cust_id = $self->rs('Public::Customer')
                            ->get_column('id')->max // 0;
    $max_cust_id++;

    my $expect_error = 1;
    $self->get_request_ok( "/${max_cust_id}/address_list", HTTP_NOT_FOUND,   $expect_error );
    $self->get_request_ok( '/INVALID_ID/address_list',     HTTP_BAD_REQUEST, $expect_error );
}

=head2 test__GET__valid__customer__address_list

Tests that Valid Requests to the API:

    /api/customer/[customerId]/address_list

returns OK and the expected Addresses are returned.

=cut

sub test__GET__valid__customer__address_list : Tests {
    my $self = shift;

    # set an Address Line that will be in XT only
    my $xt_addr_line_1 = 'address_line_1 Not In Seaview';

    # create an Address for the Customer in the DB
    my $address_rec = Test::XTracker::Data->create_order_address( {
        address_line_1 => $xt_addr_line_1,
        last_modified  => '\now()',
    } )->discard_changes;

    # get a Customer which will have a URN
    my $customer = $self->{data}->customer;
    my $cust_id  = $customer->id;

    my $order    = $self->{data}->new_order(
        channel  => $customer->channel,
        customer => $customer,
        address  => $address_rec,
    );


    note "Request Data using a Customer with a URN, should get Seaview Addresses";
    my $got = $self->get_request_ok( "/${cust_id}/address_list" );
    isa_ok( $got, 'HASH', "was Returned a HASH Ref." );
    cmp_ok( scalar( keys %{ $got} ), '>=', 1, "has at least one Address in it" );
    my $xt_address_count = scalar(
        grep { $_->{address_line_1} eq $xt_addr_line_1 }
            values %{ $got }
    );
    cmp_ok( $xt_address_count, '==', 0, "and can't find an XT DB Address" )
                    or diag "ERROR - and CAN'T find an XT DB Address: " . p( $got );
    my ( $address ) = values %{ $got };
    like( $address->{addr_key}, qr/urn/i, "and 'addr_key' looks like a URN" );


    note "Request Data using a Customer without a URN, should get XT Addresses";
    $customer->discard_changes->update( { account_urn => undef } );
    $got = $self->get_request_ok( "/${cust_id}/address_list" );
    isa_ok( $got, 'HASH', "was Returned a HASH Ref." );
    cmp_ok( scalar( keys %{ $got} ), '>=', 1, "has at least one Address in it" );
    $xt_address_count = scalar(
        grep { $_->{address_line_1} eq $xt_addr_line_1 }
            values %{ $got }
    );
    cmp_ok( $xt_address_count, '>=', 1, "and CAN find an XT DB Address" )
                    or diag "ERROR - and CAN find an XT DB Address: " . p( $got );
    ( $address ) = values %{ $got };
    unlike( $address->{addr_key}, qr/urn/i, "and 'addr_key' looks DOESN'T look like a URN" );


    note "Request Data for a Customer with NO URN and NO XT Addresses";
    my $new_customer = Test::XTracker::Data->create_dbic_customer( { channel_id => $customer->channel_id } );
    $new_customer->discard_changes->update( { account_urn => undef } );
    $got = $self->get_request_ok( '/' . $new_customer->id . '/address_list', HTTP_NOT_FOUND, 1 );
}


=head1 METHODS

=head2 get_request_ok

Helper method to make GET requests.

=cut

sub get_request_ok {
    my ($self,  $url, $expected_code, $expect_error ) = @_;

    $url             = "/api/customer${url}";
    $expected_code //= HTTP_OK;
    $expect_error  //= 0;

    my $expected_code_str = "${expected_code} - " . ( status_message( $expected_code ) // 'unknown HTTP code' );

    my $response = request
        GET $url,
        'Content-Type'      => 'application/json',
        'X-Requested-With'  => 'XMLHttpRequest';

    cmp_ok( $response->code,
        '==',
        $expected_code,
        "HTTP response code is '$expected_code_str' as expected" );

    $expect_error
        ? ok( $response->is_error, "Request to '$url' returns an error" )
        : ok( $response->is_success, "Request to '$url' returns a success" );

    my $result;

    try {
        $result = decode_json( $response->content );
        note "Response content decoded as JSON for '$url'";
    } catch {
        $result = { content => $response->content };
        note "Response content NOT valid JSON for '$url'";
    };

    return $result;
}

Test::Class->runtests;
