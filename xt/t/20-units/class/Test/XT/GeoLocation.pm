package Test::XT::GeoLocation;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

use XTracker::Config::Local qw( config_var );
use XT::GeoLocation;

sub setup: Test(setup => 0) {
    my $self = shift;
    $self->SUPER::setup;

    # ip address www.net-a-porter.com
    $self->{ip_address} = "213.253.20.102";

}

sub get_class_instance {
    my ($self, $args)  = @_;

    $args ||= {};

    return XT::GeoLocation->new({
        %$args,
    });
}

sub test_new : Tests() {
    my $self = shift;
    throws_ok(
        sub { XT::GeoLocation->new() },
        qr/\QAttribute (ip_address) is required/,
        "Missing IP Address dies ok",
    );
}

sub test_with_ip_address :Tests() {
    my $self = shift;
    local $TODO = "Mock 'Geo::IP' yet to be implemented";

        my $test_cases = [
        {
            test_title  => "Test with correct IP Address",
            setup => {
                ip_address  => $self->{ip_address},
            },
            expected    => {
                'country_code'      => 'GB',
                'country_name'      => 'United Kingdom',
                'longitude'         => '-2.0000',
                'latitude'          => '54.0000',
                'area_code'         => '0',
                'region_name'       => undef,
                'region'            => undef,
                'continent_code'    => 'EU',
                'city'              => '',
                'postal_code'       => undef,
                'time_zone'         => 'Europe/London',
                'metro_code'        => 0,
            }
       },
       {
            test_title => 'Test with incorrect IP',
            setup => {
                ip_address => '123',
            },
            expected => undef,
       },
       {
            test_title => 'Test with empty IP',
            setup => {
                ip_address => '',
            },
            expected => undef,

       }
    ];

    foreach my $case (@$test_cases) {
        my $setup = $case->{setup};
        my $geo_obj = $self->get_class_instance({
            ip_address => $setup->{ip_address},
            type       => $setup->{type}
        });

        my $got = $geo_obj->get;
        is_deeply(
            $got,
            $case->{expected},
            $case->{test_title},
        );


    }

}
