package Test::XTracker::Mock::Geo::IP;

use NAP::policy "tt", 'test';

use Test::MockObject;

sub setup_mock {
    my $self = shift;

    my $mock = Test::MockObject->new;
    $mock->fake_module(
        'Geo::IP',
        open            => \&_open,
        record_by_addr  => \&_record_by_addr,
    );

    return $mock;
}

sub _open {
    return $_[0];
}

sub _record_by_addr {
    my $self = shift;
    my $ip   = shift;

    if( $ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/ &&(($1<=255  && $2<=255 && $3<=255  &&$4<=255 )))
    {

        my $mock = Test::MockObject->new;
        $mock->set_isa('Geo::IP::Record');
        my %set_methods = (
            country_name    => 'United Kingdom',
            country_code    => 'GB',
            region          => '',
            region_name     => '',
            city            => '',
            postal_code     => '',
            latitude        => '',
            longitude       => '',
            time_zone       => '',
            area_code       => '',
            continent_code  => '',
            metro_code      => ''
        );
        $mock->set_always( $_ => $set_methods{$_}) for keys %set_methods;
        return $mock;
    }

    return;

}

1;
