package Test::XTracker::AJAX::GeoLocationWS;

use NAP::policy "tt", qw( test );

use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XTracker::Mock::Handler;
use Test::XTracker::Mock::Geo::IP;
use XTracker::AJAX::GeoLocationWS;

sub startup : Test( startup ) {
    my $self = shift;

    $self->{mock}   = Test::XTracker::Mock::Geo::IP->setup_mock;
}

sub test_with_no_ip_address : Tests() {
    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => {},
        mock_methods => {
            msg_factory => sub {},
        }
    });

    my $ajax        = new_ok('XTracker::AJAX::GeoLocationWS' => [$mock_handler]);

    my $output =  $ajax->geo_location_GET();
    cmp_ok($output->{ok}, '==', 0, 'Got Error from ajax Call');
    cmp_ok($output->{errmsg}, 'eq', 'Missing parameter: ip_address');
}


sub test_with_valid_ip_address : Tests() {

    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => { ip_address => '80.254.146.140' },
        mock_methods => {
            msg_factory => sub {},
        }
    });
    my $ajax   = new_ok('XTracker::AJAX::GeoLocationWS' => [$mock_handler]);

    my $output =  $ajax->geo_location_GET();
    cmp_ok($output->{ok}, '==', 1, 'Got OK from ajax Call');
    cmp_ok($output->{country_name}, 'eq', 'United Kingdom', 'Got country from ajax Call');


}

sub test_with_invalid_ip_address : Tests() {

    my ($self) = @_;

    my $mock_handler = Test::XTracker::Mock::Handler->new({
        param_of => { ip_address => '2.2.2' },
        mock_methods => {
            msg_factory => sub {},
        }
    });

    my $ajax   = new_ok('XTracker::AJAX::GeoLocationWS' => [$mock_handler]);

    my $output =  $ajax->geo_location_GET();
    cmp_ok($output->{ok}, '==', 1, 'Got OK from ajax Call');
    ok( !exists $output->{country_name}, "country does not exist");

}

1;
