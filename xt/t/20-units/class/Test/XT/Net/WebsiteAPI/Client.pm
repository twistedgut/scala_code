
package Test::XT::Net::WebsiteAPI::Client;
use FindBin::libs;
use parent "NAP::Test::Class";
use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ];

use HTTP::Response;
use HTTP::Headers;

use XTracker::Config::Local qw( config_var );
use Test::XTracker::Data;
use XT::Net::WebsiteAPI::Client;
use XT::Net::WebsiteAPI::TestUserAgent;

=head1 CLASS METHODS

=head1 METHODS

=cut

sub setup : Test(setup) {
    my $self = shift;
    $self->SUPER::setup();
    $self->{channel} = Test::XTracker::Data->channel_for_mrp();
}

sub get_client {
    my ($self, $args) = @_;
    $args ||= {};
    return XT::Net::WebsiteAPI::Client->new({
        channel_row => $self->{channel},
        %$args,
    });
}

sub test_new : Tests() {
    my $self = shift;
    throws_ok(
        sub { XT::Net::WebsiteAPI::Client->new() },
        qr/\QAttribute (channel_row) is required/,
        "Missing channel_row dies ok",
    );
}

sub test_defaults : Tests() {
    my $self = shift;
    my $client = $self->get_client();
    like($client->version_string, qr/XTracker Instance \(\w+\), Version \([^)]+\), IWS phase \(\d+\)/, "version_string looks fine");

}

sub test_url_base : Tests() {
    my $self = shift;

    my $expected_dc_nick = {
        DC1 => "intl",
        DC2 => "am",
    }->{ Test::XTracker::Data->whatami() } or die("Invalid DC");

    my $url_base = $self->get_client->url_base;
    like($url_base . "", qr|/$expected_dc_nick/|, "URL DC part ok");
    like($url_base . "", qr|\bmrporter\.com/|, "URL channel name part ok");
}

sub test_url_base_host_prefix : Tests() {
    my $self = shift;

    like(
        $self->get_client->url_base . "",
        qr|http://mrporter|,
        "host prefix (dev) ok",
    );
    like(
        $self->get_client({ host_prefix => "flexdev.dave" })->url_base . "",
        qr|http://flexdev.dave.mrporter|,
        "host prefix (DAVE) ok",
    );
    like(
        $self->get_client({ host_prefix => "www" })->url_base . "",
        qr|http://www.mrporter|,
        "host prefix (Live) ok",
    );
}


sub test_parse_json : Tests {
    my $self = shift;
    my $client = $self->get_client();

    my $json = "way invalid";
    throws_ok(
        sub { $client->parse_json($json) },
        qr/\($json\) contains invalid JSON \Q(malformed JSON string/,
    );

    $json = q|{"data":{"2011-11-23":"2011-11-23","2011-11-24":"2011-11-24","2011-11-25":"2011-11-25","2011-11-26":"2011-11-26","2011-11-27":"2011-11-27","2011-11-28":"2011-11-28","2011-11-29":"2011-11-29"},"errors":null}|;
    my $data = $client->parse_json($json);
    eq_or_diff(
        $data,
        {
            "data"=>  {
                "2011-11-23" => "2011-11-23",
                "2011-11-24" => "2011-11-24",
                "2011-11-25" => "2011-11-25",
                "2011-11-26" => "2011-11-26",
                "2011-11-27" => "2011-11-27",
                "2011-11-28" => "2011-11-28",
                "2011-11-29" => "2011-11-29"
            },
            "errors"=> undef,
        },
        "Parsed data structure ok",
    );
}

sub test_api_url : Tests() {
    my $self = shift;
    my $client = $self->get_client();

    like(
        $client->api_url("test/method") . "",
        qr|http://mrporter.com/\w+/api/test/method$|,
        "api_url without params ok",
    );
    like(
        $client->api_url("test/method", { abc => 123 }) . "",
        qr|http://mrporter.com/\w+/api/test/method\?abc=123$|,
        "api_url with params ok",
    );
}

sub test_check_response_errors : Tests() {
    my $self = shift;
    my $client = $self->get_client;

    my $success = HTTP::Response->new(200, "OK");
    lives_ok(
        sub {
            is(
                $client->check_response_errors($success),
                $success,
                "Error check returns same response",
            );
        },
        "200 lives ok",
    );

    my $internal_server_error = HTTP::Response->new(500, "Internal server error");
    throws_ok(
        sub { $client->check_response_errors($internal_server_error) },
        qr/\QHTTP Error (500 Internal server error)/,
        "500 dies ok",
    );
}

sub test_check_content_errors : Tests() {
    my $self = shift;
    my $client = $self->get_client;

    my $test_cases = [
        # Without error
        {
            description => "No errors element, no error",
            setup       => { response_data => {} },
        },
        {
            description => "Empty string errors element, no error",
            setup       => { response_data => { errors => "" } },
        },
        {
            description => "Undef errors element, no error",
            setup       => { response_data => { errors => undef } },
        },

        # With error
        {
            description => "String errors element, normal error",
            setup       => { response_data => { errors => "Oh, bad" } },
            expected    => { error => qr/^Error \(Oh, bad\)$/, },
        },
        {
            description => "String w newline errors element, normal error",
            setup       => { response_data => { errors => "Oh, bad\n" } },
            expected    => { error => qr/^Error \(Oh, bad\)$/, },
        },
        {
            description => "Array errors element, normal error",
            setup       => {
                response_data => { errors => ["Oh, bad", "So bad"] },
            },
            expected    => { error => qr/^Error \(\["Oh, bad", "So bad"\]\)$/, },
        },
        {
            description => "Hash errors element, normal error",
            setup       => {
                response_data => { errors => { "Oh" => "bad", "So" => "bad" } },
            },
            expected    => { error => qr/^Error \(\{"Oh": "bad", "So": "bad"\}\)$/, },
        },


    ];
    for my $case (@$test_cases) {
        my $setup = $case->{setup};
        if( my $error = $case->{expected}->{error} ) {
            throws_ok(
                sub { $client->check_content_errors($setup->{response_data}) },
                $error,
                $case->{description},
            );
        }
        else {
            lives_ok(
                sub {
                    is(
                        $client->check_content_errors(
                            $setup->{response_data},
                        ),
                        $setup->{response_data},
                        "Error check returns same data",
                    )
                },
                $case->{description},
            );
        }
    }
}

sub test_inflate_data_successfully : Tests {
    my $self = shift;
    my $client = $self->get_client;

    my $date11 = "2011-11-11";
    my $date12 = "2011-12-12";
    # Use this concrete example for testing
    my $inflate_into = "XT::Net::WebsiteAPI::Response::AvailableDate";
    my $inflated_data;
    $inflated_data = $client->inflate_data( [], $inflate_into);
    eq_or_diff($inflated_data, [ ], "Inflated data structure ok");

    $inflated_data = $client->inflate_data(
        [
            {
                delivery_date => $date12,
                dispatch_date => $date11,
            },
            {
                delivery_date => $date11,
                dispatch_date => $date11,
            },
        ],
        $inflate_into
    );
    isa_ok( $inflated_data, "ARRAY", "Return structure is array ref");
    is(@$inflated_data + 0, 2, "  and it's got the correct # of items");
    my $item = $inflated_data->[0];
    isa_ok(
        $item,
        $inflate_into,
        "  and the items are inflated into the correct class",
    );
    isa_ok(
        $item->delivery_date,
        "XT::Data::DateStamp",
        "and the field type is correctly inflated",
    );
    is(
        $item->delivery_date . "",
        "${date12}",
        "and the field value is correctly inflated",
    );
}

sub test_inflate_data_errors : Tests() {
    my $self = shift;
    my $client = $self->get_client;

    # Use this concrete example for testing
    my $inflate_into_class = "XT::Net::WebsiteAPI::Response::AvailableDate";

    my $test_cases = [
        {
            description => "Bad data datatype",
            setup       => {
                response_data => { uh => "this is the wrong datatype" },
            },
            expected    => { error => qr/\QBad response data, expected an list of objects, instead got ({"uh": "this is the wrong datatype"})/ },
        },
        {
            description => "Bad inflate class",
            setup       => {
                response_data => [ { } ],
                inflate_into  => "Not::A::Class",
            },
            expected    => { error => qr|^\QProgrammer error: missing class (Not::A::Class): Can't locate Not/A/Class.pm in| },
        },
        {
            description => "Not an object",
            setup       => {
                response_data => [ [ "this item is an array when it needs to be a hash"], { this => "is ok" } ],
            },
            expected    => { error => qr|^\QBad chunk:
(["this item is an array when it needs to be a hash"])
in response data:
([["this item is an array when it needs to be a hash"], {"this": "is ok"}])
Error:
List item is not an object.| },
        },
        {
            description => "Can't inflate a specific object (empty), Moose stack trace",
            setup       => {
                response_data => [ { } ],
            },
            expected    => { error => qr|^\QBad chunk:
({})
in response data:
([{}])
Error:
Attribute (delivery_date) is required at| },
        },
    ];
    for my $case (@$test_cases) {
        my $setup = $case->{setup};
        my $inflate_into = $setup->{inflate_into} || $inflate_into_class;
        throws_ok(
            sub {
                $client->inflate_data(
                    $setup->{response_data},
                    $inflate_into,
                ),
            },
            $case->{expected}->{error},
            "The correct exception is thrown for: $case->{description}",
        );
    }
}

sub test_get : Tests {
    my $self = shift;
    my $client = $self->get_client;

    my $path = "shipping/nominatedday/availabledate.json";
    my $args = { sku => "9001" };
    no warnings "redefine";
    no warnings "once"; ## no critic(ProhibitNoWarnings)
    local *XT::Net::WebsiteAPI::TestUserAgent::request = sub {
        my $self = shift;
        my ($request) = @_;
        like($request->headers->header("Host"), qr/^ \w+ \. com $/x, "Hosts header looks ok");

        return HTTP::Response->new(
            200,
            "OK",
            HTTP::Headers->new(),
            q|{
"data": [
        {
            "delivery_date": "2011-12-13",
            "dispatch_date": "2011-12-13"
        },
        {
            "delivery_date": "2011-12-19",
            "dispatch_date": "2011-12-19"
        }
    ],
    "errors": null
}|,
        );
    };
    my $items = $client->get({
        path             => $path,
        arg_names_values => $args,
        inflate_into     => "XT::Net::WebsiteAPI::Response::AvailableDate",
    });

    eq_or_diff(
        $items,
        [
          XT::Net::WebsiteAPI::Response::AvailableDate->new({
              dispatch_date => "2011-12-13",
              delivery_date => "2011-12-13",
          }),
          XT::Net::WebsiteAPI::Response::AvailableDate->new({
              dispatch_date => "2011-12-19",
              delivery_date => "2011-12-19",
          }),
        ],
        "Response is correct",
    );
}
