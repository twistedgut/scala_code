package Test::XT::Net::Seaview::Resource::Address;

use NAP::policy "tt", 'test', 'class';

BEGIN {
    extends 'NAP::Test::Class';
};

use Test::XTracker::Data;
use Test::XTracker::Session;
use XTracker::Config::Local qw/config_var/;
use XT::Net::Seaview::Resource::Address;
use XT::Net::Seaview::TestUserAgent;
use XT::Net::Seaview::Service;

use URI;

=head1 DESCRIPTION

Tests the basic methods of the Seaview Address resource

=cut

sub _startup : Test(startup) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{ua} = XT::Net::Seaview::TestUserAgent->new();
    $self->{service} = XT::Net::Seaview::Service->new();
    $self->{resource} = XT::Net::Seaview::Resource::Address->new(
                          { schema    => $self->{schema},
                            useragent => $self->{ua},
                            session_class => 'Test::XTracker::Session',
                            service   => $self->{service} });

    $self->{url} = 'http://mock.seaview/addresses/test';

    $self->{data_obj} = XT::Data::Address->new(
                          { schema => $self->{schema},
                            line_1 => 'Test line 1',
                            line_2 => 'Test line 2',
                            line_3 => 'Test line 3',
                            town => 'Testville',
                            postcode => 'T5T PC',
                            country_code => 'GB'});

}

sub create : Tests {
    my $self = shift;

    lives_ok sub { $self->{urn} = $self->{resource}->create($self->{data_obj})},
             'Resource can be created';

    is(URI->new($self->{urn})->scheme, 'urn', 'Returned value is a URN');

}

sub data_object : Tests {
    my $self = shift;

    my $data_obj = undef;
    lives_ok sub {$data_obj = $self->{resource}->by_uri($self->{urn})},
             'Data object can be built';

    isa_ok(ref $data_obj, 'XT::Data::Address');
}

sub get : Tests {
    my $self = shift;

    my $rep;
    lives_ok sub { $rep = $self->{resource}->get($self->{url}) },
             'Representation can be built';

    isa_ok($rep, 'XT::Net::Seaview::Representation::Address');
}

sub local_cache : Tests {
    my $self = shift;

    my $url = $self->{service}->urn_lookup($self->{urn});
    ok(exists $self->{resource}->cache->{$url},
       'Data object is stored in cache');

    lives_ok sub { $self->{resource}->clear_cache },
             'Cache can be cleared';

    ok(!exists $self->{resource}->cache->{$url},
       'Data object is no longer stored in cache');

}

sub update : Tests {
    my $self = shift;

    my $urn = undef;
    lives_ok sub {$urn = $self->{resource}->update($self->{urn},
                                                   $self->{data_obj})},
             'Resource can be updated';

    is(URI->new($urn)->scheme, 'urn', 'Returned value is a URN');
}
