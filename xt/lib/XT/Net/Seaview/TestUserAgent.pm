package XT::Net::Seaview::TestUserAgent;

use NAP::policy "tt", 'class';
use parent "LWP::UserAgent";

use File::Slurp;
use Path::Class qw/file/;
use HTTP::Response;
use XTracker::Config::Local qw(config_var);
use XTracker::Logfile qw(xt_logger);
use DateTime::Format::HTTP;
use Template;
use Data::UUID;

# This is an evil quick and dirty way to be able to return arbritrary responses
# from a fake method. The reason it's done this way is because it would take a
# lot of work to implement this correctly, using Test::XTracker::Mock::LWP.
my %response_queue;
sub add_to_response_queue {
    my ( $class, $method, $code ) = @_;
    push @{ $response_queue{ $method } }, $code;
}
sub clear_response_queue {
    my ( $class, $method ) = @_;
    if ( $method ) {
        $response_queue{ $method } = [];
    } else {
        %response_queue = ();
    }
}

=head1 NAME

XT::Net::Seaview::TestUserAgent

=head1 DESCRIPTION

Seaview test reponses

=head1 ATTRIBUTES

=head2 response_dir

=cut

has response_dir => (
    is       => 'ro',
    required => 1,
    default  => sub{ config_var("Seaview", "fake_response_dir") },
);

=head2 tt

=cut

has tt => (
    is       => 'ro',
    required => 1,
    default  => sub{ Template->new({INTERPOLATE  => 1}) },
);

=head1 METHODS

=head2 standard_headers

=cut

sub standard_headers {
    my ($class) = @_;
    return ['Content-Type' => 'application/ld+json',
            'Last-Modified' => DateTime::Format::HTTP->format_datetime()];
}


=head2 standard_text_headers

=cut

sub standard_text_headers {
    my ($class) = @_;
    return ['Content-Type' => 'text/plain',
            'Last-Modified' => DateTime::Format::HTTP->format_datetime()];
}

=head2 request

=cut

sub request {
    my ($self, $req ) = @_;

    xt_logger->info('[Fake Seaview]: ' . $req->uri);
    xt_logger->info('[Fake Seaview]: ' . $req->method);

    # The first match in the table will be used.
    my @dispatch_table = (
        {
            description   => 'Card Token',
            method_prefix => 'card_token',
            uri_match     => qr{/accounts/(?<urn>.+)/cardToken},
        },
        {
            description   => 'Address',
            method_prefix => 'address',
            uri_match     => qr{/addresses},
        },
        {
            description   => 'Account',
            method_prefix => 'account',
            uri_match     => qr{/accounts},
        },
        {
            description   => 'Customer',
            method_prefix => 'customer',
            uri_match     => qr{/customers},
        },
        {
            description   => 'Customer (BOSH)',
            method_prefix => 'customer_bosh',
            uri_match     => qr{/bosh/account/(?<urn>.+)/(?<key>.+)},
        },
    );

    my $response = undef;
    foreach my $uri ( @dispatch_table ) {

        if ( $req->uri =~ m/$uri->{uri_match}/xms ) {

            # Store the named captures.
            my $matches = { %+ };

            xt_logger->info( "[Fake Seaview]: $uri->{description} " . $req->method );
            my $method = $uri->{method_prefix} . '_' . $req->method;
            xt_logger->info( "[Fake Seaview]: Executing $method" );
            $response = $self->$method( $req, $matches );

        }

        last if defined $response;
    }

    return $response;
}

=head2 address_GET

=cut

sub address_GET {
    my ($self, $req) = @_;

    (my $address_urn = $req->uri) =~ s{http(s)?://.*/(.*)}{urn:nap:address:$2}xms;

    my $headers = $self->standard_headers;
    my $template = read_file(file($self->response_dir, 'address.json'));

    my $response = undef;
    $self->tt->process(\$template,
                       {address_urn => $address_urn},
                       \$response)
      || die $self->tt->error();

    return HTTP::Response->new( 200, 'OK',
                                HTTP::Headers->new(@$headers),
                                $response );
}

=head2 address_HEAD

=cut

sub address_HEAD {
    my ($self) = @_;

    my $headers = $self->standard_headers;

    return HTTP::Response->new( 200, 'OK',
                                HTTP::Headers->new(@$headers),
                                undef );
}

=head2 address_POST

=cut

sub address_POST {
    my ($self) = @_;

    my $headers = $self->standard_headers;
    push @$headers, 'Location' => 'http://mock.seaview/addresses/0eacab9f';

    return HTTP::Response->new( 201, 'Created',
                                HTTP::Headers->new(@$headers),
                                undef );
}

=head2 account_GET

=cut

my $_account_GET_response;

sub account_GET {
    my ($self, $req) = @_;

    (my $account_urn = $req->uri) =~ s{http(s)?://.*/(.*)}{urn:nap:account:$2}xms;

    my $headers = $self->standard_headers;
    my $template = read_file(file($self->response_dir, 'account.json'));

    my $content = undef;
    $self->tt->process(\$template,
                       {
                            account_urn => $account_urn,
                            ( $_account_GET_response ? %{ $_account_GET_response } : () ),
                       },
                       \$content)
      || die $self->tt->error();

    return HTTP::Response->new( 200, 'OK',
                                HTTP::Headers->new(@$headers),
                                $content );
}

=head2 change_account_respsone

    __PACKAGE__->change_account_respsone( {
        # put field values in here that will populate
        # the 't/data/seaview/account.json' file which
        # is passed through TT first
        field => value,
        ...
    } );

=cut

sub change_account_respsone {
    my ( $self, $args ) = @_;

    $_account_GET_response = $args // {};

    return;
}

=head2 clear_account_GET_response

This will set '$_account_GET_response' to 'undef' so
upon the next request the defaults will be used.

=cut

sub clear_account_GET_response {
    $_account_GET_response = undef;
    return;
}

=head2 account_HEAD

=cut

sub account_HEAD {
    my ($self) = @_;

    my $headers = $self->standard_headers;

    return HTTP::Response->new( 200, 'OK',
                                HTTP::Headers->new(@$headers),
                                undef );
}

=head2 account_POST

=cut

my $_account_POST_request;

sub account_POST {
    my ( $self, $req ) = @_;

    $_account_POST_request = $req;

    my $account_url
      = 'http://mock.seaview/accounts/' . Data::UUID->new->create_str();

    my $headers = $self->standard_headers;
    push @$headers, 'Location' => $account_url;

    return HTTP::Response->new( 201, 'Created',
                                HTTP::Headers->new(@$headers),
                                undef );
}

=head2 get_most_recent_account_POST_request

    $request_obj = __PACKAGE__->get_most_recent_account_POST_request;

Return the most recent Request sent to the 'account_POST' method.

=cut

sub get_most_recent_account_POST_request {
    return $_account_POST_request;
}

=head2 clear_recent_account_POST_request

Empties the Storage of the recent 'account_POST' request, call
this before each test when you want to check the most recent
'account_POST' request so you're not getting the results of
another test's request.

=cut

sub clear_recent_account_POST_request {
    $_account_POST_request = undef;
    return;
}

=head2 customer_GET

=cut

sub customer_GET {
    my ($self) = @_;

    my @headers = ('Content_Type' => 'application/ld+json');
    my $content = read_file(file($self->response_dir, 'customer.json'));

    return HTTP::Response->new( 200, 'OK',
                                HTTP::Headers->new(@headers),
                                $content );
}

=head2 card_token_GET

Returns the contents of the file 'card_token.json' in the C<response_dir>
directory. If the magic urn of 'urn:nap:account:cardToken:NONE' is
requested, then a 404 will be returned instead.

=cut

sub card_token_GET {
    my ( $self, $req, $matches ) = @_;

    unless ( my $response = $self->_try_response_queue( 'GET', 'card_token_GET' ) ) {

        if ( $matches->{urn} eq 'NONE' ) {
        # If the 'magic' urn was requested.

            _log( "Using Magic URN" );
            return $self->_generate_response( 'card_token_GET', 404 );

        } else {

            _log( "Using Default 200" );
            return $self->_generate_response( 'card_token_GET', 200 );

        }

    } else {

        return $response;

    }

}

=head2 card_token_PUT

Returns the contents of the file 'card_token_PUT_200.json' in the C<response_dir>
directory.

=cut

sub card_token_PUT {
    my ( $self, $request, $matches ) = @_;

    my $headers = HTTP::Headers->new(
        @{ $self->standard_headers }
    );

    my $content = read_file( file( $self->response_dir, 'card_token_PUT_200.json' ) );
    return HTTP::Response->new( 200, 'OK', $headers, $content );

}

sub _generate_response {
    my ( $self, $method_name, $code, $headers ) = @_;

    $headers //= $self->standard_headers;

    my $response;

    try {

        my ( $message, @content ) = read_file(
            file( $self->response_dir, "${method_name}_${code}.response" ) );

        if ( $message ) {

            chomp $message;
            chomp $content[-1] if @content;

            $response = HTTP::Response->new(
                $code,
                $message,
                HTTP::Headers->new( @$headers ),
                join( "\n", @content ) );
        }

    } catch {
        my $error = $_;

        _log( "No response found for: $method_name - $code ($error)" );

    };

    return defined $response
        ? $response
        : HTTP::Response->new( 999, 'FAILED RESPONSE GENERATION' );

}

my $_customer_bosh_GET_request;
my $_customer_bosh_PUT_request;
sub clear_last_customer_bosh_GET_request { $_customer_bosh_GET_request = undef };
sub clear_last_customer_bosh_PUT_request { $_customer_bosh_PUT_request = undef };
sub get_last_customer_bosh_GET_request   { return $_customer_bosh_GET_request }
sub get_last_customer_bosh_PUT_request   { return $_customer_bosh_PUT_request }

sub customer_bosh_GET {
    my $self = shift;
    my ( $request, $matches ) = @_;

    $_customer_bosh_GET_request = [ @_ ];

    if ( my $response = $self->_try_response_queue( 'GET', 'customer_bosh_GET', $self->standard_text_headers ) ) {

        return $response;

    } else {

        _log( "Using Default 200" );
        return $self->_generate_response( 'customer_bosh_GET', 200, $self->standard_text_headers );

    }

}

sub customer_bosh_PUT {
    my $self = shift;
    my ( $request, $matches ) = @_;

    $_customer_bosh_PUT_request = [ @_ ];

    if ( my $response = $self->_try_response_queue( 'PUT', 'customer_bosh_PUT', $self->standard_text_headers ) ) {

        return $response;

    } else {

        _log( "Using Default 200" );
        return $self->_generate_response( 'customer_bosh_PUT', 200, $self->standard_text_headers );

    }

}

sub _try_response_queue {
    my ( $self, $type, $method_name, $headers ) = @_;

    if ( my $code = shift @{ $response_queue{ $method_name } } ) {

        _log( "Using Stored Code: $code" );
        return $self->_generate_response( $method_name, $code, $headers );

    } else {

        return;

    }

}

sub _log {
    my ( $message ) = @_;

    xt_logger->info( "[Fake Seaview]: $message" );

}

