package XT::Handler::Promotion::Summary;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Plack::App::FakeApache1::Constants qw(:common);
use Data::Dump qw(pp);
use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw(xt_logger);

sub handler {
    # get a handler and set up all the common stuff
    my $handler = XTracker::Handler->new(shift);
    # set the template
    $handler->{data}{content} = 'promotion/summary.tt';

    # include some javascript extras
    $handler->{data}{js} = [
        '/javascript/NapCalendar.js',
        '/javascript/Editable.js',
    ];

    # include a TT file with DFV validation messages
    $handler->{data}{dfv} = [
        'promotion/validation_messages.tt',
    ];

    # enable YUI
    $handler->{data}{yui_enabled}   = 1;

    ## establish and call to service

    # callService will pass $handler - $data, $params
    my $status = $handler->call_service('Promotion::Summary');
    # FIXME: this should get factored up somewhere
    if (defined $status and REDIRECT == $status) {
        return REDIRECT;
    }
    else {
        # return something for the browser to show so the the user is a happy
        # bunny
        $handler->process_template( undef );
        return OK;
    }
}

1;
