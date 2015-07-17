#!/usr/bin/env perl

=head1 NAME

userpref.psgi.t - Tests that a call to XT for path "/Login" returns
                  a HTTP 200 response code

=head1 DESCRIPTION

This test proves that when XT is run under PSGI a call to /Login returns a
HTTP 200 code. The test does nothing else.

#TAGS shoulddelete

=cut

use NAP::policy "tt", 'test';

use Test::XT::PSGI;

use Plack::Test;
use HTTP::Request::Common;

my $test_psgi   = Test::XT::PSGI->new;
my $app         = $test_psgi->app;

END { done_testing; }

test_psgi $app, sub {
    my $cb = shift;
    my $res = $cb->(GET "/Login");
    # ...

    is $res->code, 200;
};
