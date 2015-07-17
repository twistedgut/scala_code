package Test::XTracker::Mock::LWP;

use NAP::policy     qw( class test );

use HTTP::Response;
use HTTP::Headers;
use LWP::UserAgent;
use Encode;
use JSON;

=head1 NAME

Test::XTracker::Mock::LWP - A class to mock LWP::UserAgent->request

=head1 SYNOPSIS

    use Test::XTracker::Mock::LWP;
    use LWP::UserAgent;

    my $mock_lwp = Test::XTracker::Mock::LWP->new();
    $mock_lwp->enabled(1);
    $mock_lwp->add_response( $mock_lwp->response_OK );

    my $lwp = LWP::UserAgent->new();
    my $request = HTTP::Request->new(POST => 'http://somehost.example.com/')'
    $request->content(...);
    my $response = $lwp->request($request);

    $mock_lwp->enabled(0);

=head2 METHODS

=cut

has original_lwp_request => (
    is          => 'ro',
    isa         => 'CodeRef',
    init_arg    => undef,
    default     => sub {
        my $lwp_meta = Class::MOP::Class->initialize('LWP::UserAgent');
        return $lwp_meta->get_method('request')->body;
    },
);

=head3 enabled

Enables or disables mocking. Pass 1 to enable or 0 to disable.

=cut

has enabled => (
    is          => 'rw',
    isa         => 'Bool',
    default     => 0,
    trigger     => \&_set_redefine,
);

=head3 add_response

Adds a new response to the end of the response list. A response is a
HTTP::Response object. See RESPONSE HELPER METHODS.

=head3 add_first_response

Adds a new response to the front of the response list so that it is the
next one used.

=head3 get_next_response

Gets the next response from the response list and removes it from the list.

=head3 get_last_response

Gets the last response from the list and removes it from the list.

=head3 response_count

Returns an integer being the size of the response list.

=head3 clear_responses

Clears the list of responses (empties the entire array).

=cut

has responses => (
    is          => 'rw',
    isa         => 'ArrayRef[HTTP::Response]',
    traits      => ['Array'],
    handles     => {
        get_next_response       => 'shift',
        get_last_response       => 'pop',
        add_response            => 'push',
        add_first_response      => 'unshift',
        response_count          => 'count',
        clear_responses         => 'clear',
    },
);

=head3 add_request

Adds a new request to the end of the request list. Here request is
HTTP::Request object;

=head3 get_next_request

Gets next request from the front of the request list.

=head3 get_last_request

Gets the last request from the list and removes it from the list.

=head3 request_count

Returns an integer being the size of the request list.

=head3 clear_requests

Clears the list of requests (empties the entire array).

=cut

has requests => (
    is          => 'rw',
    isa         => 'ArrayRef[HTTP::Request]',
    traits      => ['Array'],
    handles     => {
        get_next_request    => 'shift',
        get_last_request    => 'pop',
        add_request         => 'push',
        request_count       => 'count',
        clear_requests      => 'clear',
    },
);


BEGIN {
    # This should generate a bunch of helper methods mapping to the available
    # HTTP response codes (ie response_OK, response_Not_Found, etc)
    #
    # Each method returns a HTTP::Response object with the code and message
    # Set as per the list below and, if they are passed in, will also include
    # a specified response content and HTTP headers.

    # This list of status codes (with the exception of the last one) comes
    # from HTTP::Status. I copies the list because I could not reach into
    # HTTP::Status to read them directly.
    my %StatusCode = (
        100 => 'Continue',
        101 => 'Switching Protocols',
        102 => 'Processing',                      # RFC 2518 (WebDAV)
        200 => 'OK',
        201 => 'Created',
        202 => 'Accepted',
        203 => 'Non-Authoritative Information',
        204 => 'No Content',
        205 => 'Reset Content',
        206 => 'Partial Content',
        207 => 'Multi-Status',                    # RFC 2518 (WebDAV)
        208 => 'Already Reported',                # RFC 5842
        300 => 'Multiple Choices',
        301 => 'Moved Permanently',
        302 => 'Found',
        303 => 'See Other',
        304 => 'Not Modified',
        305 => 'Use Proxy',
        307 => 'Temporary Redirect',
        400 => 'Bad Request',
        401 => 'Unauthorized',
        402 => 'Payment Required',
        403 => 'Forbidden',
        404 => 'Not Found',
        405 => 'Method Not Allowed',
        406 => 'Not Acceptable',
        407 => 'Proxy Authentication Required',
        408 => 'Request Timeout',
        409 => 'Conflict',
        410 => 'Gone',
        411 => 'Length Required',
        412 => 'Precondition Failed',
        413 => 'Request Entity Too Large',
        414 => 'Request-URI Too Large',
        415 => 'Unsupported Media Type',
        416 => 'Request Range Not Satisfiable',
        417 => 'Expectation Failed',
        418 => 'I\'m a teapot',                   # RFC 2324
        422 => 'Unprocessable Entity',            # RFC 2518 (WebDAV)
        423 => 'Locked',                          # RFC 2518 (WebDAV)
        424 => 'Failed Dependency',               # RFC 2518 (WebDAV)
        425 => 'No code',                         # WebDAV Advanced Collections
        426 => 'Upgrade Required',                # RFC 2817
        428 => 'Precondition Required',
        429 => 'Too Many Requests',
        431 => 'Request Header Fields Too Large',
        449 => 'Retry with',                      # unofficial Microsoft
        500 => 'Internal Server Error',
        501 => 'Not Implemented',
        502 => 'Bad Gateway',
        503 => 'Service Unavailable',
        504 => 'Gateway Timeout',
        505 => 'HTTP Version Not Supported',
        506 => 'Variant Also Negotiates',         # RFC 2295
        507 => 'Insufficient Storage',            # RFC 2518 (WebDAV)
        509 => 'Bandwidth Limit Exceeded',        # unofficial
        510 => 'Not Extended',                    # RFC 2774
        511 => 'Network Authentication Required',
        99999 => 'Mock LWP Error No More Responses', # I mock the standard!
    );

    while ( my ($code, $status) = each %StatusCode ) {
        my $original_status = $status;

        # method name will be 'response_' with upper cased status appended
        # ie response_OK, response_NOT_FOUND
        $status =~ s/I'm/I am/;
        $status =~ tr/a-z \-/A-Z__/; # This is correct. Do not "fix" it.

        __PACKAGE__->meta->add_method( 'response_'.$status => sub {
            my ($self, $response, $headers) = @_;
            $response //= Encode::encode_utf8(0);
            $headers //= HTTP::Headers->new( 'X-XTracker-Mock-LWP' => 1 );

            return HTTP::Response->new($code, $original_status, $headers, $response);
        } );
    }
}

sub _set_redefine {
    my ($self, $enabled) = @_;

    no warnings 'redefine';     # We are going to redefine so no warning
    if ( ! $enabled ) {
        # Set LWP::UserAgent->request back to original
        *LWP::UserAgent::request = $self->original_lwp_request;
    }
    else {
        *LWP::UserAgent::request = sub {
            my ($mocked_self, $http_request ) = @_;

            note "I AM A MOCKED LWP::UserAgent request";

            my $response = $self->get_next_response;
            $self->add_request($http_request);

            if ( ! defined $response ) {
                $response = $self->response_MOCK_LWP_ERROR_NO_MORE_RESPONSES;
                warn "No mock responses available. Your organic flailings amuse me. I will provide a broken response for you.";
                warn "Request made to: " . $http_request->as_string;
            }

            # If there is no content set it to the content passed into request()
            # so that this functions as an "echo" method
            $response->content( $http_request->content ) unless defined $response->content;

            return $response;
        };
    }
    use warnings 'redefine';
}

=head2 get_decoded_last_request

Returns the last request, decoded from JSON.

=cut

sub get_decoded_last_request {
    my $self = shift;

    my $result;
    my $last_request = $self->get_last_request->content;

    return ''
        unless $last_request;

    try {
        $result = JSON->new->utf8->decode( $last_request );
    } catch {
        note 'Error Decoding Request (JSON): ' . $_;
        note 'Request Content:';
        explain $last_request;
    };

    return $result // '';

}

=head2 RESPONSE HELPER METHODS

A number of helper methods are available to provide HTTP::Response objects
suitable for every type of valid HTTP response. The methods are all
named response_ followed by the response type - ie:

response_OK
response_CREATED
response_INTERNAL_SERVER_ERROR
response_NOT_FOUND

Each of these methods take 2 optional parameters. The first is the
content for the response. The second optional parameter is for passing
HTTP headers suitable for passing to a standard HTTP::Response object -
ie a HTTP::Headers object.

If no parameters are passed the HTTP Response object returned will
contain the relevant code and the content will be set to the content of
the HTTP Request.

=cut

=head2 add_response_OK

    $self = $self->add_response_OK( $optional_response );

A shortcut to doing:
    $self->add_response( $self->response_OK( $optional_response ) );

Useful when you just want everything to go along the Happy Path!

Returns '$self' so you can chain other methods off it.

=cut

sub add_response_OK {
    my ( $self, $response ) = @_;
    $self->add_response( $self->response_OK( $response ) );
    return $self;
}

=head2 clear_all

    $self = $self->clear_all;

This will clear Responses & Requests that have been set or
captured. Useful to use at the beginning of some tests so
you know what state the Mocked LWP Object is in.

It returns '$self' which means other methods can be chained
off it.

=cut

sub clear_all {
    my $self = shift;

    $self->clear_responses;
    $self->clear_requests;

    return $self;
}

