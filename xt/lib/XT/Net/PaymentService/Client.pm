package XT::Net::PaymentService::Client;

use NAP::policy "tt", 'class';
with qw/XT::Net::Role::UserAgent/;

use Class::MOP::Method;
use MooseX::SemiAffordanceAccessor;

use URI;
use JSON;
use HTTP::Request;

use XTracker::Config::Local qw(config_var);
use XT::Net::PaymentService::Exception;
use MIME::Base64;
use HTTP::Headers();
use Moose::Util::TypeConstraints;

#Create a subtype of type HTTP::Headers
subtype 'Header'
    => as class_type('HTTP::Headers');


# Make 'Header' attribute to accept both ArrayRef and HashRef
# instead of HTTP::Header instance. It will be coerced into
# a new HTTPHeader instance
coerce 'Header'
    => from 'ArrayRef'
          => via { HTTP::Headers->new( @{ $_ } ) }
    => from 'HashRef'
          => via { HTTP::Headers->new( %{ $_ } ) };

=head1 NAME

XT::Net::PaymentService::Client

=head1 DESCRIPTION

Service interface class for the internal NAP Payment Service providing access
to our multiple payment gateways. The Payment Service provides a simple HTTP
API with POST requests having defined JSON request/response bodies and GET
requests having variable URLs and defined JSON response bodies.

=head1 SEE ALSO

XT::Domain::Payment

=head1 ATTRIBUTES

=head2 service_url

=cut

has service_url => (
    is => 'ro',
    isa => 'Str',
    default => sub {
        return config_var('PaymentService','service_url')
    },
);

=head2 basic_auth_username

Set authorisation username

=cut

has basic_auth_username => (
    is      => 'rw',
    isa     => 'Str',
    default => sub {
        return config_var('PaymentService','basic_auth_username') // ''
    },
);

=head2 basic_auth_password

Set authorisation password

=cut

has basic_auth_password => (
    is      => 'rw',
    isa     => 'Str',
    default => sub {
        return config_var('PaymentService','basic_auth_password') // ''
    },
);


=head2 http_GET_headers

Set HTTP headers for GET Request

=cut

has http_GET_headers => (
    is      => 'rw',
    isa     => 'Header',
    coerce  => 1,
    default => sub { HTTP::Headers->new }
);

=head2 http_POST_headers

Set HTTP headers for POST Requests

=cut

has http_POST_headers => (
    is      => 'rw',
    isa     => 'Header',
    coerce  => 1,
    default => sub { HTTP::Headers->new }
);


=head1 METHODS

=cut

sub BUILD {
    # Ensure correct SSL options are set on the user agent
    $_[0]->enable_ssl;
}

=head2 basic_authorization_string

The Base64 Encoded string of the 'basic_auth_username' & 'basic_auth_password'
attributes used for setting the 'Authorization' header. Prefixed with 'Basic '

=cut

sub basic_authorization_string {
    my $self = shift;
    return 'Basic ' . encode_base64( $self->basic_auth_username . ':' . $self->basic_auth_password );
}

=head2 init_card_token_payment

Initiate a payment interaction with the Payment Service, using a Card
Token. This is an initialisation step - no actual payment process is
associated with this request until further calls are made with the
initialisation reference returned by this call

=cut

__PACKAGE__->meta->add_method(
    init_card_token_payment => __PACKAGE__->make_POST_method('init_card_token_payment',
                                                  'init-card-token'));

=head2 settle_payment

Settle an existing authorisation for a defined amount. The pre-authorisation
is identified by submitting a pre-authorisation reference in the POST body

=cut

__PACKAGE__->meta->add_method(
    settle_payment => __PACKAGE__->make_POST_method('settle_payment',
                                                    'settle'));

=head2 refund_payment

Refund a defined amount to a specific card used for a previous settlement. The
settlement is identified by submitting a settlement reference in the POST body

=cut

__PACKAGE__->meta->add_method(
    refund_payment => __PACKAGE__->make_POST_method('refund_payment',
                                                    'refund'));


=head2 cancel_preauth

Cancel a previously requested pre-authorisation, releasing the reservation of
funds from the card. The pre-authorisation is identified by the
pre-authorisation reference in the POST body.

=cut

__PACKAGE__->meta->add_method(
    cancel_preauth => __PACKAGE__->make_POST_method('cancel_preauth',
                                                    'cancel'));

=head2 get_all_customer_cards

Get all the saved cards associated with a customer. The customer is identified
using a customerID and cardToken in the POST body.

=cut

__PACKAGE__->meta->add_method(
   get_all_customer_cards  => __PACKAGE__->make_POST_method('get_all_customer_cards',
                                                    'get-all-customer-cards'));

=head2 save_card

Create a new saved card for a customer. The customer is identified
using a customerID and cardToken in the POST body.

=cut

__PACKAGE__->meta->add_method(
    save_card => __PACKAGE__->make_POST_method('save_card',
                                                    'save-card'));

=head2 reauthorise_address

The PSP needs to be told when a Shipping Address changes.

Initially just required for PayPal payments.

=cut

__PACKAGE__->meta->add_method(
    reauthorise_address => __PACKAGE__->make_POST_method( 'reauthorise_address', 'reauthorise/address' )
);

=head2 init_with_payment_session


=cut

__PACKAGE__->meta->add_method(
    init_with_payment_session => __PACKAGE__->make_POST_method('init_with_payment_session',
                                                    'init-with-payment-session'));

=head2 preauth_with_payment_session


=cut

__PACKAGE__->meta->add_method(
    preauth_with_payment_session => __PACKAGE__->make_POST_method('preauth_with_payment_session',
                                                    'preauth-with-payment-session'));

=head2 payment_session

Create a new payment session for a customer with the client session
C<clientSessionId>. The customer is identified using a C<customerCardToken>
in the POST body.

At the time of writing, both the fields mentioned above are required and:

    * The C<clientSessionId> must be an alphanumeric string and the allowed
      characters are [a-zA-Z0-9 -.].

    * The C<customerCardToken> must be a 64 character, lowercase string.

=cut

__PACKAGE__->meta->add_method(
    payment_session => __PACKAGE__->make_POST_method('payment_session',
                                                    sub { 'payment-session/'
                                                        . ( delete $_[0]->{clientSessionId} ) }));

=head2 getinfo_payment

Request the payment information for a specific pre-authorisation. Relevant
pre-authorisation reference is the final part of the URL. Returns a JSON
document in the response body with the payment information for this
transaction plus any previous transactions on the specific card used.

=cut

__PACKAGE__->meta->add_method(
    getinfo_payment => __PACKAGE__->make_GET_method('getinfo_payment',
                                                    sub { 'payment-information/'
                                                          . ( $_[0]->{reference} // '' ) }));

=head2 getorder_numbers

Match up external PSP transaction references with associated order numbers and
return these in a JSON response body.

=cut

__PACKAGE__->meta->add_method(
    getorder_numbers => __PACKAGE__->make_POST_method('getorder_numbers',
                                                        'order-numbers-by-internal-references' ));

=head2 get_card_token

Get a new card token for use in other Payment Service methods.

=cut

__PACKAGE__->meta->add_method(
    get_new_customer_card_token => __PACKAGE__->make_GET_method('get_new_customer_card_token',
                                                     sub { 'new-customer-card-token' }));

=head2 amount_exceeds_provider_threshold

Find out if a Payments Threshold will be exceeded for a new Value.

=cut

__PACKAGE__->meta->add_method(
    amount_exceeds_provider_threshold => __PACKAGE__->make_GET_method('exceeds_provider_threshold',
                                                    sub { 'exceeds-provider-threshold/'
                                                          . $_[0]->{reference} . '/'
                                                          . $_[0]->{newAmount} } )
);

=head2 get_card_detail_status

Get the status of the last call made to the /payment method.

=cut

__PACKAGE__->meta->add_method(
    get_card_details_status => __PACKAGE__->make_GET_method('get_card_details_status',
                                                     sub { 'card-details-status/'
                                                           . $_[0]->{paymentSessionId} }));

=head2 get_refund_information

Get refund information for a given settlement reference.

=cut

__PACKAGE__->meta->add_method(
    get_refund_information => __PACKAGE__->make_GET_method('get_refund_information',
                                                     sub { 'refund-information/'
                                                           . $_[0]->{settleReference} }));

=head2 payment_amendment

Reauthorise payments for order amendements

=cut

__PACKAGE__->meta->add_method(
    payment_amendment => __PACKAGE__->make_POST_method('payment_amendment',
                                                    'payment-amendment'));

=head2 payment_replacement

Replaces items in orders after settlement.

=cut

__PACKAGE__->meta->add_method(
    payment_replacement => __PACKAGE__->make_POST_method('payment_replacement',
                                                    sub { 'orderItem/replacement' }));

=head2 req_POST

Create an HTTP POST request to the Payment Service with any data encoded as
JSON and added to the request body.

=cut

sub req_POST {
    my ($self, $relative_url, $data) = @_;

    my $url = URI->new($self->service_url . $relative_url);

    # Sets specified header field only if no previous value was set for the specified field
    $self->http_POST_headers->init_header(
        Authorization  => $self->basic_authorization_string
    );
    $self->http_POST_headers->init_header(
        'Content-Type' => 'application/json'
    );

    my $req = HTTP::Request->new(
        POST => $url->as_string,
        $self->http_POST_headers,
    );
    $req->content( JSON->new->utf8->encode($data) );

    return $req;
}

=head2 req_GET

Create an HTTP GET request to the Payment Service.

=cut

sub req_GET {
    my ($self, $relative_url) = @_;

    my $url = URI->new($self->service_url . $relative_url);

    #Sets specified header field only if no previous value was set for the specified field
    $self->http_GET_headers->init_header(
        Authorization => $self->basic_authorization_string,
    );

    my $req = HTTP::Request->new(
        GET => $url->as_string,
        $self->http_GET_headers
    );


    return $req;
}

=head2 decode_json_content

Create a valid data structure from a JSON string

=cut

sub decode_json_content {
    my ($self, $json) = @_;

    my $decoded = {};

    # Throw on JSON decode error
    try{
        $decoded = JSON->new->utf8->decode($json);
    }
    catch {
        XT::Net::PaymentService::Exception->throw(
          { code  => 0, error => "Invalid JSON: $json" });
    };

    return $decoded;
}

=head2 make_POST_method

Create a named Payment Service POST method

=cut

sub make_POST_method {
    my ($class, $name, $url_builder) = @_;

    return
      Class::MOP::Method->wrap(
          sub {
              my ($self, $data) = @_;

              # Validate parameters?

              # Set up request
              my $req = $self->req_POST(
                $class->build_url( $url_builder, $data ),
                $data );

              # Send request
              my $response = $self->useragent->request($req);
              my $content  = $response->content;

              # Throw on HTTP error
              if($response->is_error){
                  XT::Net::PaymentService::Exception->throw(
                      { code  => $response->code, error => $content });
              }
              else{
                  # ok
              }

              # Only attempt to parse and return the JSON if it's defined and
              # not empty or null, otherwise return undef.
              return ( defined $content && $content ne '' && $content ne 'null' )
                  ? $self->decode_json_content( $content )
                  : undef;

          },
          ( name => $name, package_name => $class )
      );
}

=head2 make_GET_method

Create a named Payment Service GET method

=cut

sub make_GET_method {
    my ($class, $name, $url_builder) = @_;

    return
      Class::MOP::Method->wrap(
          sub {
              my ($self, $data) = @_;

              # Validate parameters?

              # Set up request
              my $req = $self->req_GET(
                $class->build_url( $url_builder, $data ) );

              # Send request
              my $response = $self->useragent->request($req);
              my $content  = $response->content;


              # Throw on HTTP error
              if($response->is_error){
                  XT::Net::PaymentService::Exception->throw(
                      { code  => $response->code, error => $content });
              }
              else{
                  # ok
              }

              # Only attempt to parse and return the JSON if it's defined and
              # not empty or null, otherwise return undef.
              return ( defined $content && $content ne '' && $content ne 'null' )
                  ? $self->decode_json_content( $content )
                  : undef;

          },
          ( name => $name, package_name => $class )
      );
}

=head2 build_url( $builder, $data )

If C<$builder> is a CODE reference, execute it, passing in C<$data> and
return the result. If C<$builder> is NOT a CODE reference, just return
C<$builder>.

=cut

sub build_url {
    my ( $class, $builder, @data ) = @_;

    # Build URL
    return ref( $builder )  eq 'CODE'
        ? $builder->( @data )
        : $builder;

}
