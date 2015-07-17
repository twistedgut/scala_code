#!/usr/bin/env perl
use NAP::policy qw( tt test );

BEGIN { use parent 'NAP::Test::Class' }

=head1 NAME

Test::XT::DC::Controller::API::Payment

=head1 DESCRIPTION

Test the XT::DC::Controller::API::Payment class.

=cut

use DDP;
use JSON;
use Test::XT::Data;
use HTTP::Request::Common;
use Catalyst::Test 'XT::DC';
use XTracker::Constants::FromDB qw( :orders_payment_method_class );
use Mock::Quick;

sub startup : Tests( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    use_ok 'XT::DC::Controller::API::Payment';

    $self->{data} = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Channel',
            'Test::XT::Data::Customer',
            'Test::XT::Data::Order',
            'Test::XT::Data::PreOrder',
        ]
    } );

    $self->{data}->schema->txn_begin;
    $self->{data}->new_order;
    $self->{data}->create_payment( 0 );

    $self->{payment_method} = $self->{data}->schema
        ->resultset('Orders::PaymentMethod')
        ->create( {
            payment_method                  => 'Test Payment Method',
            payment_method_class_id         => $ORDERS_PAYMENT_METHOD_CLASS__CARD,
            string_from_psp                 => 'TESTPAYMENTMETHOD',
            notify_psp_of_address_change    => 0,
            display_name                    => 'Test Payment Method',
        } );

    $self->{order_payment} = $self->{data}->{order}->payments->create( {
        psp_ref             => 'test-psp-ref',
        preauth_ref         => 'test-preauth-ref',
        settle_ref          => 'test-settle-ref',
        fulfilled           => 0,
        valid               => 1,
        payment_method_id   => $self->{payment_method}->id,
    } );

    $self->{preorder_payment} = $self->{data}->pre_order->create_related( pre_order_payment => {
        psp_ref             => 'test-psp-ref-preorder',
        preauth_ref         => 'test-preauth-ref-preorder',
        settle_ref          => 'test-settle-ref-preorder',
        fulfilled           => 0,
        valid               => 1,
    } );

    # Fake the response from the ACL has_permission method, so we can test
    # the API with and without permissions.
    $self->{acl} = qtakeover( 'XT::AccessControls' );
    $self->{acl}->override( has_permission => sub { return $self->{has_permission} } );

    # We need to fake the application session, so it thinks we're logged in.
    # We're not testing authentication, so this just returns static data.
    $self->{xtdc} = qtakeover( 'XT::DC' );
    $self->{xtdc}->override( session => sub { return { operator_id => 1, user_id => 'it.god' } } );

}

sub shutdown : Tests( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown();

    $self->{data}->schema->txn_rollback;

    # Explicitly destroy the control objects, so the mocked objects are restored.
    $self->{acl}  = undef;
    $self->{xtdc} = undef;

}

sub setup : Tests( setup => no_plan ) {
    my $self = shift;

    # By default every test should run with permissions granted.
    $self->{has_permission} = 1;

}

=head1 TESTS

=head2 test__GET__root

=cut

sub test__GET__root : Tests {
    my $self = shift;

    $self->get_request_ok( '/', 404, 1 );

}

=head2 test__GET__valid_id

=cut

sub test__GET__valid_id : Tests {
    my $self = shift;

    my $order_id    = $self->{order_payment}->id;
    my $preorder_id = $self->{preorder_payment}->id;

    $self->get_request_ok( "/order/$order_id", 404, 1 );
    $self->get_request_ok( "/preorder/$preorder_id", 404, 1 );

}

=head2 test__GET__invalid_id

=cut

sub test__GET__invalid_id : Tests {
    my $self = shift;

    $self->get_request_ok( "/order/invalid-id", 404, 1 );
    $self->get_request_ok( "/preorder/invalid-id", 404, 1 );

}

=head2 test__GET__valid_id_with_an_invalid_method

=cut

sub test__GET__valid_id_with_an_invalid_method : Tests {
    my $self = shift;

    my $order_id    = $self->{order_payment}->id;
    my $preorder_id = $self->{preorder_payment}->id;

    $self->get_request_ok( "/order/$order_id/invalid-method", 404, 1 );
    $self->get_request_ok( "/preorder/$preorder_id/invalid-method", 404, 1 );

}

=head2 test__GET__invalid_id_with_an_invalid_method

=cut

sub test__GET__invalid_id_with_an_invalid_method : Tests {
    my $self = shift;

    $self->get_request_ok( "/order/invalid-id/invalid-method", 404, 1 );
    $self->get_request_ok( "/preorder/invalid-id/invalid-method", 404, 1 );

}

=head2 test__GET__valid_request

=cut

sub test__GET__valid_request : Tests {
    my $self = shift;

    my $fake_data = [
        {
            success         => 0,
            reason          => 'FAILED',
            amountRefunded  => 60000,
            dateRefunded    => '2014-01-01T12:34:56.000+0000',
        },
        {
            success         => 1,
            reason          => 'ACCEPTED',
            amountRefunded  => 30000,
            dateRefunded    => '2014-02-02T12:34:56.000+0000',
        },
    ];

    # Notice the order has been swapped, this is to test the sorting.
    my $expected = [
        {
            success         => 'Yes',
            reason          => 'ACCEPTED',
            amountRefunded  => 300,
            dateRefunded    => '2014-02-02 12:34:56',
        },
        {
            success         => 'No',
            reason          => 'FAILED',
            amountRefunded  => 600,
            dateRefunded    => '2014-01-01 12:34:56',
        },
    ];

    my $fake = $self->fake_psp_get_refund_history(
        sub { return $fake_data } );

    my $order_id    = $self->{order_payment}->id;
    my $preorder_id = $self->{preorder_payment}->id;

    my $order_result    = $self->get_request_ok( "/order/$order_id/refund_history" );
    my $preorder_result = $self->get_request_ok( "/preorder/$preorder_id/refund_history" );

    cmp_deeply( $order_result, $expected,
        'Got the correct data back' );

    cmp_deeply( $preorder_result, $expected,
        'Got the correct data back' );

}

=head2 test__GET__valid_request_with_upstream_missing_data

=cut

sub test__GET__valid_request_with_upstream_missing_data : Tests {
    my $self = shift;

    my $fake = $self->fake_psp_get_refund_history(
        sub { return undef } );

    my $order_id    = $self->{order_payment}->id;
    my $preorder_id = $self->{preorder_payment}->id;

    $self->get_request_ok( "/order/$order_id/refund_history", 404, 1 );
    $self->get_request_ok( "/preorder/$preorder_id/refund_history", 404, 1 );

}

=head2 test__GET__valid_request_with_upstream_failure

=cut

sub test__GET__valid_request_with_upstream_failure : Tests {
    my $self = shift;

    my $fake = $self->fake_psp_get_refund_history(
        sub { die 'Something Went Wrong' } );

    my $order_id    = $self->{order_payment}->id;
    my $preorder_id = $self->{preorder_payment}->id;

    $self->get_request_ok( "/order/$order_id/refund_history", 500, 1 );
    $self->get_request_ok( "/preorder/$preorder_id/refund_history", 500, 1 );

}

sub test__GET__valid_request_with_no_permissions : Tests {
    my $self = shift;

    # Set to false, so the application will think no permissions are granted.
    $self->{has_permission} = 0;

    my $order_id    = $self->{order_payment}->id;
    my $preorder_id = $self->{preorder_payment}->id;

    $self->get_request_ok( "/order/$order_id/refund_history", 401, 1 );
    $self->get_request_ok( "/preorder/$preorder_id/refund_history", 401, 1 );

}

=head1 METHODS

=head2 get_request_ok

=cut

sub get_request_ok {
    my ($self,  $url, $expected_code, $expect_error ) = @_;

    $url            = "/api/payment${url}";
    $expected_code  //= 200;
    $expect_error   //= 0;

    my $response = request
        GET $url,
        'Content-Type'      => 'application/json',
        'X-Requested-With'  => 'XMLHttpRequest';

    cmp_ok( $response->code,
        '==',
        $expected_code,
        "HTTP response code is '$expected_code' as expected" );

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

sub fake_psp_get_refund_history {
    my ($self,  $response ) = @_;

    my $psp_get_refund_history = sub {
        note '*** IN FAKE psp_get_refund_history ***';
        return $response->();
    };

    my @payments = (
        qtakeover( 'XTracker::Schema::Result::Orders::Payment' ),
        qtakeover( 'XTracker::Schema::Result::Public::PreOrderPayment' ),
    );

    $_->override( psp_get_refund_history => $psp_get_refund_history )
        foreach @payments;

    return \@payments;

}

Test::Class->runtests;
