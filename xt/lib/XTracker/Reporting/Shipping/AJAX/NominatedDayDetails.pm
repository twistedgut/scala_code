package XTracker::Reporting::Shipping::AJAX::NominatedDayDetails;
use NAP::policy "tt";

use Plack::App::FakeApache1::Constants qw(:common);
use Time::ParseDate;
use DateTime;
use DateTime::Format::DateParse;
use JSON;

use XTracker::Config::Local 'config_var';
use XTracker::Database qw( :common );
use XTracker::Handler;

sub handler {
    my $r = shift;
    my $handler = XTracker::Handler->new($r);
    my $schema = $handler->{schema};
    my $date = $handler->{param_of}->{d} // "";
    my $json = JSON->new
        ->utf8
        ->canonical(1)
        ->indent(0)->space_before(0)->space_after(1);

    my $response = { };
    my $dt = DateTime::Format::DateParse->parse_datetime($date,
        config_var("DistributionCentre", "timezone")
    );
    if (!$dt) {
        $response = { error => "Cannot parse as a date: '$date'" };
    } else {
        my $data = $schema->resultset('Public::Shipment')
            ->nominated_day_status_count_for_day($dt);

        $response = { status => $data };
    }

    # write out response
    $r->print( $json->encode($response) );
    return OK;
}

1;
