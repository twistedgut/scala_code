package XTracker::AJAX::GeoLocationWS;

use NAP::policy "tt";
use XTracker::Handler;
use XTracker::Logfile 'xt_logger';
use XTracker::Constants::Ajax           qw( :ajax_messages );
use JSON;
use Plack::App::FakeApache1::Constants qw( :common HTTP_METHOD_NOT_ALLOWED );
use XT::GeoLocation;

=head1 NAME

XTracker::AJAX::GeoLocationWS

=head1 DESCRIPTION

This module returns JSON output containing Geolocation information for given IP Address.

Webservice Call : localhost://AJAX/GeoLocationWS?ip_address= <ip_address>

Output: {"country_name":"United Kingdom","longitude":"-0.0931","area_code":0,"country_code":"GB",
"region_name":"London, City of","region":"H9","continent_code":"EU","ok":1,"city":"London",
"postal_code":null,"latitude":"51.5142","time_zone":"Europe/London","metro_code":0}

=cut

my $logger = xt_logger(__PACKAGE__);

sub handler {
    my ($req) = @_;
    my $handler = XTracker::Handler->new($req);
    my $ajax = __PACKAGE__->new($handler);

    my $result = $ajax->process();

    # convert data hash to json
    $handler->{r}->print( encode_json( $handler->{data}{output}) )
        if $result == OK;

    return $result;
}

sub new {
    my ($class, $handler) = @_;

    my $self = {
        handler => $handler,
    };

    return bless($self, $class);
}

sub process {
    my $self = shift(@_);

    # handle GET request
    if ($self->{handler}{r}->method eq 'GET') {
        $self->{handler}->{data}{output} = $self->geo_location_GET($self);
        return OK;
    }
    else {
        return HTTP_METHOD_NOT_ALLOWED;
    }
}

sub geo_location_GET {
    my ($self) =  @_;

    if ($self->{handler}->{param_of}{ip_address}) {
        $logger->debug('An ip_address was provided so lets use that');
        return try {
            my $obj = XT::GeoLocation->new({
                ip_address => $self->{handler}->{param_of}{ip_address},
            });
            return $self->_generate_ok($obj->get);
        }
        catch {
            $logger->warn($_);
            return $self->_generate_error("Unable to Obtain any information for given IP Address");
        };
    } else {
        return $self->_generate_error("Missing parameter: ip_address");
    }

    return;

}
sub _generate_error {
    my ($self, $error, $data) = @_;
    $data = {} unless ($data);
    my $output = {
        %{$data},
        ok     => 0,
        errmsg => $error,
    };
    return $output;
}

sub _generate_ok {
    my ($self, $data) = @_;
    $data = {} unless ($data);
    return {
        %{$data},
        ok     => 1,
    }
}

1;

