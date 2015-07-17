package Test::NAP::Pims::API;
use NAP::policy qw/class test/;

use Test::XTracker::LoadTestConfig;
use Test::MockObject::Builder;
use NAP::Pims::API;

BEGIN { extends 'NAP::Test::Class' };

sub test__get_quantities :Tests {
    my ($self) = @_;

    for my $test (
        {
            name => 'OK result parsed correctly',
            setup   => {
                mock_get => {
                    'pims.nap/quantity' => Test::MockObject::Builder->build({
                        set_isa => 'HTTP::Response',
                        mock => {
                            is_success      => 1,
                            decoded_content => q/[{ "boxCode": "BOX-1", "quantity": 5 }]/,
                        }
                    })
                }
            },
            expected => {
                returned_json => [{
                    boxCode     => 'BOX-1',
                    quantity    => 5,
                }]
            },
        },
        {
            name => 'Failure result parsed correctly',
            setup   => {
                mock_get => {
                    'pims.nap/quantity' => Test::MockObject::Builder->build({
                        set_isa => 'HTTP::Response',
                        mock => {
                            is_success      => 0,
                            code            => 500,
                            status_line     => 'Boxes all soggy'
                        }
                    })
                }
            },
            expected => {
                returned_exception => 'NAP::Pims::API::Exception',
                exception_data => {
                    status_code => 500,
                    description => 'Boxes all soggy'
                }
            },
        }
    ) {
        subtest $test->{name} => sub {
            my $api = $self->_setup_get_quantities_test($test);

            if($test->{expected}->{returned_exception}) {
                throws_ok { $api->get_quantities} $test->{expected}->{returned_exception};
                my $exception = $@;
                is($exception->status_code, $test->{expected}->{exception_data}->{status_code}, 'Exception status code as expected');
                is($exception->description, $test->{expected}->{exception_data}->{description}, 'Exception description as expected');
            } else {
                eq_or_diff(
                    $api->get_quantities,
                    $test->{expected}->{returned_json},
                    'Response parsed to JSON correctly'
                );
            }

        };
    }
}

sub _setup_get_quantities_test {
    my ($self, $test) = @_;

    my $mock_ua = Test::MockObject::Builder->build({
        set_isa     => 'LWP::UserAgent',
        mock    => {
            get => sub {
                my ($self, $url) = @_;
                return $test->{setup}->{mock_get}->{$url}
                    if exists $test->{setup}->{mock_get}->{$url};
                die 'Mock UserAgent can not handle URL: ' . $url;
            }
        }
    });

    NAP::Pims::API->new( ua => $mock_ua, url => 'pims.nap' );
}