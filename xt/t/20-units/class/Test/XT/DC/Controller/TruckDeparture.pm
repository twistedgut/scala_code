package Test::XT::DC::Controller::TruckDeparture;
use NAP::policy qw/tt test/;
use parent 'NAP::Test::Class';
use JSON;
use HTTP::Request::Common;
use URI::Escape;
use Try::Tiny;
use Catalyst::Test 'XT::DC';

=head1 Test::XT::DC::Controller::TruckDeparture
    Unit tests for the TruckDeparture controller

=cut

sub test__url_parsing :Tests {

    my ( $self ) = @_;

    for my $test (
        {
            name    => "Well-formed URL",
            path    => '/truckdepartures/calendar_events',
            params  => 'start=2014-04-27&end=2014-06-08&timezone=Europe%2FLondon',
            result  =>  {
                returns_ok  => 1,
            }
        },
        {
            name    => "Malformed URL",
            path    => '/truckdepartures/calendar_events',
            params  => 'start=2014-04-27&end=2014-06-08&timezone=Europe%2FLondon',
            result  =>  {
                returns_ok  => 1,
            }
        },
        {
            name    => "Missing parameters",
            path    => '/truckdepartures/calendar_events',
            params  => 'start=2014-04-27',
            result  =>  {
                returns_ok  => 0,
                error       => "Start or end date not defined",
            }
        },
        {
            name    => "Disordered start and end parameters",
            path    => '/truckdepartures/calendar_events',
            params  => 'start=2014-06-08&end=2014-04-27',
            result  =>  {
                returns_ok  => 0,
                error       => "Start date is later than end date",
            }
        },
        {
            name    => "Range greater than 366 days",
            path    => '/truckdepartures/calendar_events',
            params  => 'start=2013-06-08&end=2015-04-27',
            result  =>  {
                returns_ok  => 0,
                error       => "Date range exceeds one year",
            }
        }
    ) {
        subtest $test->{name} => sub {

            my $response = request GET( $test->{path} . '?' . $test->{params},
                'Content-Type'  => 'application/json');
            # Check passes pass and fails fail
            # We're not checking for scalar equality,
            # but for the same truth evaluation
            ok($response->is_success == $test->{result}->{returns_ok},
                "Call returns the correct success status");

            # Check the response is well-formed JSON
            my $response_content = undef;
            try {
                $response_content = decode_json($response->content);
            };
            ok($response_content,
                "Result is well-formed JSON") or diag($response->content);

            # Check successes for the right format and
            # failures for the right error message
            if($test->{result}->{returns_ok}) {
                is(ref($response_content), 'ARRAY',"Event array is an array");
            }
            else {
                is($response_content->{error}, $test->{result}->{error},
                    "Error reports the expected reason for failure");
            }
        }
    }
}
