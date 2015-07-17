package XT::Net::Seaview::Resource;

use NAP::policy "tt", 'class';

use Log::Log4perl;
use HTTP::Request;
use HTTP::Status qw/ :constants /;
use URI;
use Time::HiRes qw/gettimeofday/;
use Data::Dump qw/dump/;

use XTracker::Logfile qw(xt_logger);
use XTracker::Session;
use XTracker::Constants qw/$APPLICATION_OPERATOR_ID/;
use XTracker::Config::Local qw(config_var);

use XT::Net::Seaview::Service;
use XT::Net::Seaview::Exception::NetworkError;
use XT::Net::Seaview::Exception::ServerError;
use XT::Net::Seaview::Exception::ClientError;
use XT::Net::Seaview::Exception::ResponseError;
use XT::Net::Seaview::Exception::ParameterError;
use XT::Net::Seaview::Representation::Error::JSONLD;

=head1 NAME

XT::Net::Seaview::Resource

=head1 DESCRIPTION

The Seaview resource classes provide a way of interfacing with Seaview server
resources. This is a base resource class, which provides generic HTTP
interaction methods and common attributes

=head1 ATTRIBUTES

=cut

has useragent => (
    is       => 'ro',
    isa      => 'LWP::UserAgent',
    required => 1,
);

=head2 useragent_timeout

=cut

has useragent_timeout => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        config_var("Seaview", "useragent_timeout") || 5,
    },
);

=head2 service

Seaview service instance

=cut

has service => (
    is      => 'ro',
    isa     => 'XT::Net::Seaview::Service',
    default => sub { XT::Net::Seaview::Service->new() },
);

=head2 session_class

User session class

=cut

has session_class => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    default => 'XTracker::Session',
);

=head2 operator_username

Username from the XT session

=cut

has operator_username => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_operator_username',
);

sub _build_operator_username {
    my $self = shift;
    my $username = undef;

    my $session = $self->session_class->session();
    if(defined $session->{operator_username}){
        $username = $session->{operator_username}
    }
    else{
        $username
          = $self->schema->resultset("Public::Operator")
                         ->find($APPLICATION_OPERATOR_ID)->name;
    }

    return $username;
}

=head2 user_credentials

User credentials from the XT session

=cut

has user_credentials => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_user_credentials',
);

sub _build_user_credentials {
    my $self = shift;
    my $cred_str = undef;

    my $NO_DEPARTMENT = 0;
    my $NO_ROLE = 0;

    my $session = $self->session_class->session();

    $cred_str = $self->operator_username
                . ':' . ( $session->{department_id} // $NO_DEPARTMENT )
                . ',' . ( $session->{auth_level}    // $NO_ROLE );

    return $cred_str;
}

=head2 logger

The logging object

=cut

has logger => (
    is  => 'ro',
    isa => 'Log::Log4perl::Logger',
    default => sub { return xt_logger(); }
);

=head2 cache

Representation cache

=cut

has cache => (
    is       => 'rw',
    isa      => 'HashRef',
    init_arg => undef,
    default  => sub{ {} },
);

=head1 METHODS

=head2 request_GET

Create a GET request

=cut

sub request_GET {
    my ($self,$url) = @_;

    # Build the request
    my $req = HTTP::Request->new(GET => $url->as_string);

    return $req;
}

=head2 request_HEAD

Create a HEAD request

=cut

sub request_HEAD {
    my ($self,$url) = @_;

    # Build the request
    my $req = HTTP::Request->new(HEAD => $url->as_string);

    return $req;
}

=head2 request_PUT

Create a PUT request

=cut

sub request_PUT {
    my ($self, $url, $rep) = @_;

    # Build the request
    my $req = HTTP::Request->new(PUT => $url->as_string);

    # Request body content
    $req->content($rep->to_rep);

    return $req;
}

=head2 request_POST

Create a POST request

=cut

sub request_POST {
    my ($self, $url, $rep) = @_;

    # Build the request
    my $req = HTTP::Request->new(POST => $url->as_string);

    # Request body content
    $req->content($rep->to_rep);

    return $req;
}

=head2 make_request

Fire the request at the service

=cut

sub make_request {
    my ($self, $req) = @_;

    # Set opts
    $self->useragent->timeout($self->useragent_timeout);

    # Try the request
    my $response = undef;
    $response = $self->useragent->request($req);

    if(defined $response){
        if($self->network_error($response)){
            XT::Net::Seaview::Exception::NetworkError->throw(
                { error => $response->content });
        }
        elsif($self->server_error($response)){
            my $err_rep = XT::Net::Seaview::Representation::Error::JSONLD->new(
                {src => $response->content});
            XT::Net::Seaview::Exception::ServerError->throw(
                { code  => $response->code,
                  error => $err_rep->error_msg, });
        }
        elsif($self->client_error($response)){
            my $err_rep = XT::Net::Seaview::Representation::Error::JSONLD->new(
                { src => $response->content });
            XT::Net::Seaview::Exception::ClientError->throw(
                { code  => $response->code,
                  error => $err_rep->error_msg, });
        }
        else{
            # ok
        }
    }

    return defined $response ? $response : ();
}

=head2 meta_by_uri

Returns the remote HTTP headers (as an HTTP::Headers object) for the resource
identified by the input URI

=cut

sub meta_by_uri {
    my ($self, $uri) = @_;

    my $url = undef;
    if( $uri =~ /^urn:/xmsg ){
        $url = $self->service->urn_lookup($uri)
    }
    else {
        $url = $uri;
    }

    my $headers = $self->head($url);
    return defined $headers ? $headers : ();
}


=head2 head

Generic network method returning HTTP headers for a resource

=cut

sub head {
    my ($self, $input_url) = @_;
    my $response = undef;

    my $url = URI->new($input_url);

    # Create the request
    my $req = $self->request_HEAD($url);
    $self->set_get_headers($req);

    # Pang!
    $response = $self->make_request($req);

    return $response->headers;
}

=head2 get

HTTP GET a remote resource and create a representation

=cut

sub get {
    my ($self, $url_str) = @_;

    my $rep = undef;
    my $url = URI->new($url_str);

    # Create the request
    my $req = $self->request_GET($url);
    $self->set_get_headers($req);

    # Pang!
    my $response = $self->make_request($req);

    # Check for expected media type
    if( defined $response ){
        unless($response->content_type eq $self->read_rep_class->media_type){
            XT::Net::Seaview::Exception::ResponseError->throw(
                { error => 'Unexpected response content-type' });
        }

        # Create a representation using the response body content
        $rep = $self->read_rep_class->new({ src   => $response->content,
                                            _meta => $response->headers,
                                            schema => $self->schema });

        # Check the representation is usable
        unless($rep->identity){
            XT::Net::Seaview::Exception::ResponseError->throw(
                {error => $response->content});
        }
    }

    return $rep;
}


=head2 create

Create a Seaview resource. This is currently via HTTP POST

=cut

sub create {
    my ($self, $data_obj) = @_;

    my $url = URI->new($self->service->resource($self->collection_key));

    # Convert XT::Data:: to Seaview Representation
    my $rep = $self->write_rep_class->new({src => $data_obj,
                                           schema => $self->schema});


    # Create the request
    my $req = $self->request_POST($url, $rep);
    $self->set_post_headers($req);

    # Send the request
    my $response = $self->make_request($req);
    my $location = $response->header('Location');

    unless(defined $location){
        XT::Net::Seaview::Exception::ResponseError->throw(
          {error => 'New account resource location not present in response'});
    }

    return $self->get($location)->identity;
}


=head2 update

Transfer the resource state to the remote server

=cut

sub update {
    my ($self, $urn, $data_obj) = @_;

    my $url_str = $self->service->urn_lookup($urn);
    my $url = URI->new($url_str);

    # Create a representation of the address to send in the request body.
    my $rep = $self->write_rep_class->new({src => $data_obj,
                                           schema => $self->schema });

    # Create POST request with the representation as the body
    my $req = $self->request_POST($url, $rep);

    # Add the necessary HTTP headers
    $self->set_post_headers($req);
    $self->set_conditional_headers($req, $data_obj);

    # Lukino!
    my $response = $self->make_request($req);

    return $urn;
}


=head2 replace

Transfer the resource state to the remote server

=cut

sub replace {
    my ($self, $urn, $data_obj) = @_;

    my $url_str = $self->service->urn_lookup($urn);
    my $url = URI->new($url_str);

    # Create a representation of the address to send in the request body.
    my $rep = $self->write_rep_class->new({src => $data_obj,
                                           schema => $self->schema });

    # Create PUT request with the representation as the body
    my $req = $self->request_PUT($url, $rep);
    $self->set_put_headers($req);

    # Do it NOW!
    my $response = $self->make_request($req);

    return $urn;
}

=head2 by_urn

Returns the XT data object corresponding to the resource identified by the
input URI.

=cut

sub by_uri {
    my ($self, $uri) = @_;

    my $do = undef;

    # dispatch to get method
    my $rep = $self->fetch($uri);

    if( defined $rep ){
        # dispatch to DO builder
        $do = $rep->as_data_obj;
    }

    return $do;
}

=head2 fetch

Takes a URI and returns a resource representation. The representation is
stored in a local cache for the life of the object (unless removed
manually). The cached version is returned if present saving a network trip

=cut

sub fetch {
    my ($self, $uri) = @_;

    XT::Net::Seaview::Exception::ParameterError->throw(
      { error => 'URI not supplied' }) unless defined $uri;

    my $rep = undef;
    my $url = undef;
    my $urn = undef;

    if( $uri =~ /^urn:/xmsg ){
        $url = $self->service->urn_lookup($uri);
    }
    else {
        $url = $uri;
    }

    if(defined $self->cache->{$url}){
        $self->logger->debug("[Cache Hit] $url");
        $rep = $self->cache->{$url};
    }

    $self->logger->debug("[Network Request] $url");
    $rep = $self->get($url);
    $self->cache->{$url} = $rep;

    return defined $rep ? $rep : ();
}

=head2 clear_cache

Clear the... um... cache

=cut

sub clear_cache {
    %{$_[0]->cache} = ();
    return 1;
}

=head2 set_put_headers

Set the HTTP PUT request headers

=cut

sub set_put_headers {
    my ($self, $req) = @_;

    # Add the necessary HTTP headers
    $req->header('NAP-User-Credentials' => $self->user_credentials);
    $req->header('NAP-Request-ID' => $self->generate_request_id);
    $req->header('Content-Type' => $self->write_rep_class->media_type);

    return $req;
}

=head2 set_get_headers

Set the HTTP GET request headers

=cut

sub set_get_headers {
    my ($self, $req) = @_;

    # Add the necessary HTTP headers
    $req->header('X-Seaview-User-Credentials' => $self->user_credentials);
    $req->header('NAP-User-Credentials' => $self->user_credentials);
    $req->header('NAP-Request-ID' => $self->generate_request_id);
    $req->header('Accept' => $self->read_rep_class->media_type);

    return $req;
}

=head2 set_post_headers

Set the HTTP POST request headers

=cut

sub set_post_headers {
    my ($self, $req) = @_;

    # Add the necessary HTTP headers
    $req->header('X-Seaview-User-Credentials' => $self->user_credentials);
    $req->header('NAP-User-Credentials' => $self->user_credentials);
    $req->header('NAP-Request-ID' => $self->generate_request_id);
    $req->header('Content-Type' => $self->write_rep_class->media_type);
    $req->header('Accept' => $self->read_rep_class->media_type);

    return $req;
}

=head2 set_conditional_headers

Set the HTTP request headers for conditional processing

=cut

sub set_conditional_headers {
    my ($self, $req, $data_obj) = @_;

    my $http_date
      = DateTime::Format::HTTP->format_datetime( $data_obj->last_modified );
    $req->header( 'If-Unmodified-Since' => $http_date );

    return $req;
}

=head2 generate_request_id

Generate a unique request id for use in the NAP-Request-ID HTTP header. This
can be be used for request tracking through the application

=cut

sub generate_request_id {
    my $self = shift;

    my $req_id_root = 'urn:nap:request:xt:';
    my $dc = config_var('DistributionCentre', 'name');
    my $uniqueness = gettimeofday();

    return $req_id_root . lc($dc)
                        . ':' . lc($self->operator_username)
                        . ':' . $uniqueness;
}

=head1 CLASS METHODS

=head2 network_error

Returns true if response indicates client is unable to contact server

=cut

sub network_error {
    my ($class, $response) = @_;

    return $response->is_error
      && $response->content =~ /Can't connect to.*/;
}

=head2 server_error

Returns true if server responds with a HTTP status in the 500- range

=cut

sub server_error {
    my ($class, $response) = @_;

    return $response->is_error
      && (   $response->code >= HTTP_INTERNAL_SERVER_ERROR );
}

=head2 client_error

Returns true if server responds with a HTTP status in the 400-499 range

=cut

sub client_error {
    my ($class, $response) = @_;

    return $response->is_error
      && (   $response->code >= HTTP_BAD_REQUEST
          && $response->code <  HTTP_INTERNAL_SERVER_ERROR);
}

=head2 dump_request

Use Data::Dump to show request objects

=cut

sub dump_request {
    my ($class, $req) = @_;

    my $dumpstr = dump $req;
    $dumpstr   .= dump $req->url;
    $dumpstr   .= dump $req->headers;

    return $dumpstr;
}

=head2 dump_response

Use Data::Dump to show response objects

=cut

sub dump_response {
    my ($class, $res) = @_;

    my $dumpstr = dump $res;
    $dumpstr   .= dump $res->headers;

    return $dumpstr;
}
