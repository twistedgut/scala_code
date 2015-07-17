package XTracker::DHL::XMLRequest;

use NAP::policy "tt", 'class';

use IO::Socket::SSL;
use Carp ();
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use XTracker::Config::Local;
use XTracker::Logfile qw(xt_logger);
use HTTP::Status qw/ :constants /;

has client_host => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has request_xml => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub send_xml_request {
    my $self = shift;

    my $ua = LWP::UserAgent->new(
        env_proxy         => 1,
        protocols_allowed => [qw(https)],
        timeout           => config_var('DHL', 'dhl_api_timeout') // 10,
        cookie_jar        => {},
        agent             => 'Java/1.5.0',
        keep_alive        => 1,
    );
    my $uri = URI->new('','https');
    $uri->scheme("https");
    $uri->host($self->client_host);
    $uri->path('/XMLShippingServlet');

    xt_logger->info("Making request to DHL at $uri");
    my $req = POST $uri,
        Content => $self->request_xml,
    ;

    my $res = $ua->request($req);

    my $dhl_error = not ($res->header('Client-Warning') &&
                         $res->header('Client-Warning') =~ /Internal response/i &&
                         $res->code() == HTTP_INTERNAL_SERVER_ERROR);

    if ($res->is_success) {
        my $body = $res->decoded_content;

        if ( my ($xml) = $body =~ m{(\<.*\>)}s ) {
            xt_logger->info("XML response received from DHL");
            return $xml;
        }
        else {
            Carp::croak("Unexpected Response From DHL Service:\n\n$body\n\n");
        }

    }
    else {
        my $message;
        if ($dhl_error) {
            $message = "An error has occurred on DHL side. Please ask Service Desk to contact DHL with error code ";
        } else {
            $message = "LWP::UserAgent error requesting XML content from DHL: ";
        }
        Carp::croak($message, $res->status_line);
    }
}


1;
