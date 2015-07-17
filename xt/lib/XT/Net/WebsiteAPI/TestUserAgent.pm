package XT::Net::WebsiteAPI::TestUserAgent;
use NAP::policy "tt";
use parent "LWP::UserAgent";

=head1 DESCRIPTION

This class overrides LWP:UserAgent->get(), and provides methods for
faking specific responses instead of calling the actual web site API
endpoint.

This is the WebsiteAPI::Client UserAgent class used by the tests and
test server after you configure your nap_dev.properties:

    WEBSITE_API_USERAGENT_CLASS  "XT::Net::WebsiteAPI::TestUserAgent"

=cut

use Storable qw/ freeze thaw /;
use File::Path qw/ make_path /;
use File::Slurp;
use Guard;
use Scalar::Util qw/ blessed /;

use XTracker::Config::Local qw( config_var );
use XTracker::Logfile qw( xt_logger );

use XT::Net::WebsiteAPI::Client;

# A possible way to extend this module could be to fake multiple
# requests. Probably with some kind of file name convention.

my $fake_response_dir = config_var("WebsiteAPI", "fake_response_dir");
my $default_response_file = "$fake_response_dir/response.storable";

sub request {
    my ($self, $request) = @_;

    my $uri = $request->uri;
    xt_logger->info("Returning fake response for Website API call to ($uri)");

    -r $default_response_file or return $self->standard_fake_response($uri);
    my $response_blob = read_file($default_response_file); # or die
    my $response = thaw($response_blob);

    if($self->ok_to_clear($response)) {
        $self->clear_fake_response();
    }
    else {
        xt_logger->info("    keeping the response for next request");
    }

    return $response;
}

sub ok_to_clear {
    my ($self, $response) = @_;
    blessed($response)        or return 1;
    $response->can("headers") or return 1;

    return ! $response->headers->header("X-Fake-Keep");
}

sub setup_fake_response {
    my ($self, $response) = @_;

    make_path($fake_response_dir);
    -d $fake_response_dir or die("Could not create dir ($fake_response_dir)\n");
    write_file( $default_response_file, freeze($response) ); # or die
}

sub clear_fake_response {
    my ($class) = @_;
    unlink($default_response_file);
    -e $default_response_file and die("Could not delete requested response file ($default_response_file)");
}

sub standard_fake_response {
    my ($self, $url) = @_;
    xt_logger->info("    which is a standard fake response");

    if($url =~ m|/shipping/nominatedday/availabledate.json|) {
        xt_logger->info("        for /shipping/nominatedday/availabledate.json");
        return $self->shipping_nominatedday_availabledate();
    }
    xt_logger->info("        which is empty");

    return $self->empty_response();
}

sub shipping_nominatedday_availabledate {
    my ($self) = @_;

    # a week's worth of available dates from now
    my @available_dates =
        map {
            {
                delivery_date => $_->ymd,
                dispatch_date => $_->clone->subtract(days => 1)->ymd,
            };
        }
        map { DateTime->now->add(days => $_) }
        1..7;

    return $self->create_ok_response([ @available_dates ]);
}

sub empty_response {
    my ($self) = @_;
    $self->create_ok_response([]);
}

sub create_ok_response {
    my ($self, $data, $keep) = @_;
    $keep //= 0;

    my $json = XT::Net::WebsiteAPI::Client->json_parser->encode(
        {
            data   => $data,
            errors => undef,
        },
    );

    my $response = HTTP::Response->new(
        200,
        "OK",
        HTTP::Headers->new(
            "Content-Type" => "application/json",
            ( $keep ? ("X-Fake-Keep" => 1) : () ),
        ),
        $json,
    );

    return $response;
}

=head2 with_get_response_data(@$data, $sub_ref, $keep = 0)

Run $sub_ref->() with this user agent set up to return a 200 OK
response with @$data.

If $keep, don't clear the fake response after each call, so repeated
requests will get the same response. The fake response will still be
cleared out before with_get_response_data returns.

=cut

# extract to more general one which can return 404, timeouts etc if
# needed
sub with_get_response {
    my ($class, $data, $sub_ref, $keep) = @_;
    $keep //= 0;

    my $response = ( blessed($data) && $data->isa("HTTP::Response") )
        ? $data
        : $class->create_ok_response($data, $keep);

    $class->setup_fake_response($response);
    my $response_guard = guard { $class->clear_fake_response() };

    return $sub_ref->();
}
