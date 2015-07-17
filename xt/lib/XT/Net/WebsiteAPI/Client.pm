package XT::Net::WebsiteAPI::Client;
use NAP::policy "tt", "class";
with qw/XTracker::Role::WithSchema
        XT::Net::Role::UserAgent/;
use Module::Runtime 'require_module';
use URI::URL;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use HTTP::Headers;
use JSON;

use XTracker::Config::Local qw( config_var );
use XTracker::Logfile qw( xt_logger );
use XTracker::Version;

=head1 NAME

XT::Net::WebsiteAPI::Client - API Client for calling a channelized web site

=head1 DESCRIPTION

Website API client for a Channel.

=cut

has channel_row => (
    is       => "ro",
    isa      => "XTracker::Schema::Result::Public::Channel",
    required => 1,
);

has host_prefix => (
    is      => "ro",
    lazy    => 1,
    default => sub { config_var("WebsiteAPI", "host_prefix") // "" },
);

has url_base => (
    is      => "ro",
    isa     => "URI::URL",
    lazy    => 1,
    default => \&_build_url_base,
);

has +useragent_class => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        config_var("WebsiteAPI", "useragent_class") || "LWP::UserAgent",
    },
);

sub _build_url_base {
    my $self = shift;

    my $instance_name = lc(config_var("XTracker", "instance")); # am/intl/etc.

    my @host_parts = (
        $self->host_prefix,
        lc($self->channel_row->name),
    );
    my $host = join(".",  grep { $_ } @host_parts);

    return URI::URL->new("http://$host/$instance_name/api");
}

=head2 get({ :$path, :%$arg_names_values, :$inflate_into }) : @$rows[ $inflate_into_class ]

Make request to $path URL (e.g. "nominatedday/days") in the API with
the $arg_names_values (hash ref) parameters.

Verify the reponse is JSON with two top level keys: "errors"
(optional), and "data" (array of hashes). Inflate the data items into
$inflate_into_class.

Die on errors.

=cut

sub get {
    my ($self, $args) = @_;
    my $url = $self->api_url( $args->{path}, $args->{arg_names_values} );
    my $inflate_into_class = $args->{inflate_into};

    my $inflated_data = eval {
        my $response = $self->check_response_errors(
            $self->make_request($url),
        );
        my $response_data = $self->check_content_errors(
            $self->parse_json($response->content),
        );
        $self->inflate_data(
            $response_data->{data},
            $inflate_into_class,
        );
    };
    if($@) {
        my $e = "Could not GET ($url): $@";
        xt_logger->error($e);
        die($e);
    }

    return $inflated_data;
}

sub api_url {
    my ($self, $path, $get_args) = @_;
    $get_args //= {};
    my $url = URI::URL->new($self->url_base . "/$path");
    $url->query_form($get_args);
    return $url;
}

sub make_request {
    my ($self, $url) = @_;

    # The Tomcat app server requires the Host header to be present
    # (which is fair enough since it's required by HTTP/1.1)
    my $request = HTTP::Request->new(
        GET => $url,
        HTTP::Headers->new( Host => $url->host ),
    );

    return $self->useragent->request($request);
}

sub check_response_errors {
    my ($self, $response) = @_;
    $response->is_success or die("HTTP Error (" . $response->status_line . ")\n");
    return $response;
}

sub check_content_errors {
    my ($self, $response_data) = @_;

    if(my $error = $response_data->{errors}) {
        $error = $self->serialise_json_error_message($error) if( ref($error) );

        chomp($error);
        die("Error ($error)\n");
    }

    return $response_data;
}

sub inflate_data {
    my ($self, $data, $inflate_into_class) = @_;
    $data or return [];
    ref($data) eq "ARRAY" or die("Bad response data, expected an list of objects, instead got (" . $self->serialise_json_error_message($data) . ")\n");
    try { require_module $inflate_into_class }
    catch {
        die("Programmer error: missing class ($inflate_into_class): $_");
    };

    return [
        map {
            my $arg_value = $_;
            my $object = eval {
                ref($arg_value) eq "HASH" or die("List item is not an object.\n");
                $inflate_into_class->new($arg_value);
            };
            if(my $e = $@) {
                chomp($e);
                die("Bad chunk:\n("
                        . $self->serialise_json_error_message($arg_value)
                        . ")\nin response data:\n("
                        . $self->serialise_json_error_message($data)
                        . ")\nError:\n$e\n");
            }

            $object;
        }
        @$data
    ];
}

my $json_parser_singleton;
sub json_parser {
    my ($class) = @_;
    return $json_parser_singleton ||= JSON->new
        ->utf8
        ->canonical(1)
        ->indent(0)->space_before(0)->space_after(1);
}

sub parse_json {
    my ($self, $json_text) = @_;

    my $data = eval { $self->json_parser->decode($json_text) };
    if (my $e = $@) {
        die("($json_text) contains invalid JSON ($e)\n");
    }

    return $data;
}

sub serialise_json_error_message {
    my ($self, $data_structure) = @_;
    return eval { $self->json_parser->encode($data_structure) } // "<N/A>";
}

1;
