
package Test::XT::Net::WebsiteAPI::Client::NominatedDay;
use FindBin::libs;
use lib "$ENV{XTDC_BASE_DIR}/t/20-units/class";
use parent "Test::XT::Net::WebsiteAPI::Client";
use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ];

use LWP::UserAgent;
use HTTP::Response;
use Data::Printer;

use XT::Data::DateStamp;
use XTracker::Config::Local qw( config_var );

use XT::Net::WebsiteAPI::Client::NominatedDay;
use XT::Net::WebsiteAPI::Response::AvailableDate;
use XT::Net::WebsiteAPI::TestUserAgent;

sub sku_shipping_charge {
    my $dc = config_var('DistributionCentre', 'name');
    state $dc_skus = {
        DC1 => {
            nominated_day => "9000210-001",
            regular       => "900003-001",
        },
        DC2 => {
            nominated_day => "9000211-001",
            regular       => "900045-002",
        },
    };
    die "Unknown DC ($dc)" unless ($dc_skus->{$dc});
    return $dc_skus->{$dc};
}

sub get_client {
    my ($self, $args) = @_;
    $args ||= {};
    return XT::Net::WebsiteAPI::Client::NominatedDay->new({
        channel_row => $self->{channel},
        %$args,
    });
}

sub test_new : Tests() {
    my $self = shift;
    throws_ok(
        sub { XT::Net::WebsiteAPI::Client::NominatedDay->new() },
        qr/\QAttribute (channel_row) is required/,
        "Missing channel_row dies ok",
    );
}

sub test_available_days_bad_params : Tests {
    my $self = shift;
    my $client = $self->get_client;

    my $params = "(country|sku|postcode)";
    throws_ok(
        sub {$client->available_dates() },
        qr/^Mandatory parameters '$params', '$params', '$params' missing in call to XT::Net::WebsiteAPI::Client::NominatedDay::available_dates/,
        "Missing params throws ok"
    );

    my $sku = $self->sku_shipping_charge->{nominated_day};
    throws_ok(
        sub {
            $client->available_dates({
                sku      => $sku,
                country  => "Blah",
                postcode => "ABC",
            }),
        },
        qr/"Blah"/,
        "Bad country throws ok"
    );

    throws_ok(
        sub {$client->available_dates({
            sku      => $sku,
            country  => "UK",
            postcode => "ABC",
            state    => "Alabama",
        }) },
        qr/"Alabama"/, # Should be AL or whatever
        "Bad state throws ok"
    );

    throws_ok(
        sub {$client->available_dates({
            sku      => "Bad SKU",
            country  => "UK",
            postcode => "ABC",
        }) },
        qr/\QUnknown Shipping Charge SKU (Bad SKU)/,
        "Missing SKU throws ok",
    );

}

sub test_available_days_ok : Tests {
    my $self = shift;
    my $client = $self->get_client;

    my $date = XT::Data::DateStamp->from_string("2012-12-12");
    my $response = [ {
        delivery_date => "$date",
    } ];

    my $test_cases = [
        {
            description => "Nominated Day sku, canned response",
            setup => {
                sku => $self->sku_shipping_charge->{nominated_day},
            },
            expected => {
                response => [
                    XT::Net::WebsiteAPI::Response::AvailableDate->new({
                        delivery_date => $date,
                    }),
                ],
            },
        },
        {
            description => "Regular sku, empty reponse (in spite of canned response)",
            setup => {
                sku => $self->sku_shipping_charge->{regular},
            },
            expected => {
                response => [ ],
            },
        },
    ];
    for my $case (@$test_cases) {
        my $sku = $case->{setup}->{sku};
        my $test_args = [
            { sku => $sku, country => "GB", postcode => "W5 ABC123" },
            { sku => $sku, country => "US", postcode => "W5 ABC123", state => "NY" },
            { sku => $sku, country => "US", postcode => "W5 ABC123", state => undef },
            { sku => $sku, country => "US", postcode => "W5 ABC123", state => "" },
        ];
        for my $args (@$test_args) {
            XT::Net::WebsiteAPI::TestUserAgent->with_get_response(
                $response,
                sub {
                    my $items = $client->available_dates($args);
                    eq_or_diff(
                        $items,
                        $case->{expected}->{response},
                        "Correct canned response",
                    ) or diag("With args: " . Data::Printer::p($args));
                },
            );
        }
    }

}
