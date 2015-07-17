#!/usr/bin/env perl

use NAP::policy "tt", qw( test );

use LWP::UserAgent;
use Test::XTracker::Mock::LWP;

use HTTP::Status qw( :constants );

my $mock_lwp = Test::XTracker::Mock::LWP->new();

isa_ok( $mock_lwp, "Test::XTracker::Mock::LWP");

$mock_lwp->enabled(1);  # LWP::UserAgent->request is now mocked

$mock_lwp->add_response( $mock_lwp->response_OK );
ok( $mock_lwp->response_count == 1, "There is 1 response in the response queue");

my $lwp = LWP::UserAgent->new();
my $request = HTTP::Request->new(GET => 'http://www.example.com/');

note("I am about to call request");

my $response = $lwp->request($request);

ok( $response->is_success, "Request has a sucessful response" );
ok( $response->code == HTTP_OK, "Response code is HTTP OK" );

$mock_lwp->add_response( $mock_lwp->response_NOT_FOUND );
$request = HTTP::Request->new(GET => 'http://www.example.com/');
$response = $lwp->request($request);

ok( $response->is_error, "Request has an error" );
ok( $response->code == HTTP_NOT_FOUND, "Response code is HTTP Not Found" );

$mock_lwp->add_response( $mock_lwp->response_OK("Test Data") );
$mock_lwp->add_response( $mock_lwp->response_CREATED );

$request = HTTP::Request->new(GET => 'http://www.example.com/');
$response = $lwp->request($request);

ok( $response->is_success, "Request has a sucessful response" );
ok( $response->code == HTTP_OK, "Response code is HTTP OK" );
ok( $response->content eq 'Test Data', "Response content is correct" );

$request = HTTP::Request->new(GET => 'http://www.example.com/');
$response = $lwp->request($request);

ok( $response->is_success, "Request has a sucessful response" );
ok( $response->code == HTTP_CREATED, "Response code is HTTP Created" );

done_testing();
