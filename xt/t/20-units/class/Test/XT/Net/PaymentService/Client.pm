package Test::XT::Net::PaymentService::Client;
use NAP::policy 'tt', 'test';
use parent "NAP::Test::Class";


use XT::Net::PaymentService::Client;
use XTracker::Config::Local qw( config_var );
use Test::XTracker::Mock::LWP;
use MIME::Base64;
use Test::XTracker::Mock::PSP;

sub startup  : Test(startup => no_plan) {
    my $self = shift;
    $self->SUPER::startup;


    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state
    Test::XTracker::Mock::PSP->unmock_payment_service_client();
    $self->{setup_mock_obj} = Test::XTracker::Mock::LWP->new();
    $self->{setup_mock_obj}->enabled(1);
}

sub shut_down : Test(shutdown => no_plan) {
    my $self = shift;

    Test::XTracker::Mock::PSP->mock_payment_service_client();
    # disable Mock LWP
    $self->{setup_mock_obj}->enabled(0);

    Test::XTracker::Mock::PSP->use_all_original_methods();
}

sub get_class_instance {
    my ($self, $args) = @_;

    my $psp = XT::Net::PaymentService::Client->new({
        %$args,
    });
}

=head1 METHODS

=head2 test_getinfo_payment

Tests that to get payment information from psp the new end point (payment-information rather
than payment-info) is used and authentication header includes username and password.

=cut

sub test_getinfo_payment : Tests() {
    my $self = shift;


    my $psp = $self->get_class_instance({});
    $self->{setup_mock_obj}->add_response( $self->{setup_mock_obj}->response_OK('[1]') );

    $psp->getinfo_payment({ reference => '123123' });
    my $req = $self->{setup_mock_obj}->get_last_request;

    like($req->uri, qr/payment-information/,"Endpoint is changed from payment-info to payment-information");

    my $username = config_var('PaymentService','basic_auth_username')//'';
    my $password = config_var('PaymentService','basic_auth_password')//'';

    cmp_ok( $req->header('Authorization'),
        'eq',
        'Basic '.encode_base64($username . ':' . $password),
        "HTTP Header has username and password"
    );

}

=head2 test_reauthorise_address

Tests the call to the 'reauthorise/address' service on the PSP works
and has the Basic Authorization passed to it in the Header of the
request.

=cut

sub test_reauthorise_address : Tests() {
    my $self = shift;

    my $psp = $self->get_class_instance({});
    $self->{setup_mock_obj}->add_response( $self->{setup_mock_obj}->response_OK('[1]') );

    $psp->reauthorise_address( { reference => '123123' } );
    my $req = $self->{setup_mock_obj}->get_last_request;

    like( $req->uri, qr{reauthorise/address}, "Endpoint is 'reauthorise/address'" );

    my $username = config_var('PaymentService','basic_auth_username') // '';
    my $password = config_var('PaymentService','basic_auth_password') // '';

    is( $req->header('Authorization'), 'Basic ' . encode_base64( "${username}:${password}" ),
                                "HTTP Header has username and password" );

}

=head2 test_get_all_customer_cards


=cut

sub test_get_all_customer_cards : Tests() {
    my $self = shift;

    my $psp = $self->get_class_instance({});
    $self->{setup_mock_obj}->add_response( $self->{setup_mock_obj}->response_OK('[1]') );

    my $payload = {
        site                => "nap_am",
        userId              => "11",
        customerId          => "100001234",
        admin               => "false",
        customerCardToken   => "a91268ec8fa6c5394bac97945801dd9e09dd2f02c71ceb405088127da9c7c4de"
    };

    $psp->get_all_customer_cards( $payload );
    my $req = $self->{setup_mock_obj}->get_last_request;

    like( $req->uri, qr/get-all-customer-cards/, "Endpoint is 'get-all-customer-cards'" );

    my $username = config_var('PaymentService','basic_auth_username') // '';
    my $password = config_var('PaymentService','basic_auth_password') // '';

    is( $req->header('Authorization'), 'Basic ' . encode_base64( "${username}:${password}" ),
                                "HTTP Header has username and password" );

}

=head2 test_http_GET_headers

checks that attribute http_GET_headers is settings headers correctly

=cut

sub test_http_GET_headers : Tests() {
    my $self = shift;

    # Tests with different Authorisation headers
    my $psp = $self->get_class_instance({});
    my $encoded_str = encode_base64("test" . ':' . "user");
    my $expected_header = "Basic".$encoded_str;

    # Since we are using MooseX::SemiAffordanceAccessor, it requires the set
    # methods to be prefixed by set_
    $psp->set_http_GET_headers({
        'Authorization' => $expected_header,
        'MIME_Version'  => '60.0',
    });

    $self->{setup_mock_obj}->add_response( $self->{setup_mock_obj}->response_OK('[1]') );
    $psp->getinfo_payment({ reference => '123123' });
    my $req = $self->{setup_mock_obj}->get_last_request;

    cmp_ok($req->header('Authorization'), 'eq', $expected_header, "HTTP authorisation header was updated as expected");
    cmp_ok($req->header('MIME_Version'), 'eq', "60.0", "HTTP MIME header was as expected");


}

=head2 test_http_POST_headers

Checks that the attribute http_POST_headers is setting headers correctly.

=cut

sub test_http_POST_headers : Tests {
    my $self = shift;

    my $psp = $self->get_class_instance({});

    # Tests with a different Authorisation header
    my $encoded_str     = encode_base64('test:user');
    my $expected_header = "Basic ${encoded_str}";

    # Since we are using MooseX::SemiAffordanceAccessor, it requires the set
    # methods to be prefixed by set_
    $psp->set_http_POST_headers( {
        'Authorization' => $expected_header,
        'MIME_Version'  => '60.0',
    } );

    $self->{setup_mock_obj}->add_response( $self->{setup_mock_obj}->response_OK('[1]') );
    $psp->reauthorise_address( { reference => '123123' } );
    my $req = $self->{setup_mock_obj}->get_last_request;

    is( $req->header('Authorization'), $expected_header,
                        "HTTP authorisation header was updated as expected" );
    is( $req->header('MIME_Version'), '60.0',
                        "HTTP MIME header was as expected" );
    # POST requests should have a default 'Content-Type' header set
    is( $req->header('Content-Type'), 'application/json',
                        "'Content-Type' header has the default of 'application/json'" );
}
