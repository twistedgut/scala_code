package Test::XTracker::Cookies::Role::ManipulatesCookies;
use NAP::policy "tt", qw/test class/;
BEGIN { extends 'NAP::Test::Class'; }

use Test::MockObject;
use XTracker::Cookies;
use Data::Dumper;

sub test__cookies :Tests {
    my ($self) = @_;

    my ($mock_request, $mock_response) = $self->_create_mock_request();
    my $test_cookies = XTracker::Cookies->get_cookies({
        request     => $mock_request,
        response    => $mock_response,
    });
    isa_ok($test_cookies, 'XTracker::Cookies');

    is($test_cookies->get_cookie('me_me_me')->{value}, 'I love cookies. Nom!',
       'get_cookie() returns correct cookie value');

    $test_cookies->set_cookie('created', {
        value => 'I have been created',
    });
    my $cookie_data = $mock_response->cookies()->{'created'};
    is($cookie_data->{value}, 'I have been created',
       'New cookie has been set in response object');

    $test_cookies->unset_cookie('created');
    $cookie_data = $mock_response->cookies()->{'created'};
    ok(!defined($cookie_data), 'Cookie is no longer set in response object');
}

sub _create_mock_request {
    my ($self) = @_;

    # Create mock Plack::Request and Plack::Response
    # objects for our cookie role to play with

    my $mock_response = Test::MockObject->new();
    my $response_cookies = {};
    $mock_response->mock('cookies', sub { $response_cookies });
    $mock_response->set_isa('Plack::Response');

    my $mock_request = Test::MockObject->new();
    $mock_request->mock('cookies', sub { {
        'ignore' => { value => 'Nothing to see here' },
        'me_me_me' => { value => 'I love cookies. Nom!' },
    } });
    $mock_request->set_isa('Plack::Request');

    return ($mock_request, $mock_response);
}

Test::Class->runtests;
