package XT::GeoLocation;
use NAP::policy "tt", "class";

use XTracker::Config::Local qw ( config_var );
use Geo::IP;
use XTracker::Logfile qw(xt_logger);

=head2 XT::GeoLocation

This module returns GeoLocation related information for
a given ip address

my $gi =  XT::GeoLocation->new({
    ip_address => '<ip_address>'
});

$data = $gi->get();

=cut

has ip_address => (
    is => "ro",
    isa => "Str",
    required => 1,
);

has logger => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        return xt_logger();
    },
    init_arg => undef,
);

sub get {
    my $self = shift;

    my $data ;
    return try {

        my $file_path = config_var('SystemPaths','geoloc_db_file_path');
        my $file_name = config_var('GeoLocation','db_filename');
        my $gi = Geo::IP->open($file_path."/".$file_name, GEOIP_STANDARD);

        my $geo_info = $gi->record_by_addr($self->ip_address);

        $data->{country_code} = $geo_info->country_code;
        $data->{country_name} = $geo_info->country_name;
        $data->{region}       = $geo_info->region;
        $data->{region_name}  = $geo_info->region_name;
        $data->{city}         = $geo_info->city;
        $data->{postal_code}  = $geo_info->postal_code;
        $data->{latitude}     = $geo_info->latitude;
        $data->{longitude}    = $geo_info->longitude;
        $data->{time_zone}    = $geo_info->time_zone;
        $data->{area_code}    = $geo_info->area_code;
        $data->{continent_code} = $geo_info->continent_code;
        $data->{metro_code} = $geo_info->metro_code;

        return $data if ($data);
        return;
    }
    catch {
        $self->logger->error("Couldn't get results from Geo::IP module - $_" );
        return;
    };
}

1;
