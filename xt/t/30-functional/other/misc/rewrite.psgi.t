#!/usr/bin/env perl

use NAP::policy     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
}

=head1 NAME

rewrite.t - Tests the use of 'Plack::Middleware::Rewrite' in 'xt.psgi'

=head1 DESCRIPTION

Tests that any URL Rewrites that are happening in 'xt.psgi' are
doing what is expected of them.

#TAGS psgi

=cut


use Test::XTracker::Data;

use HTTP::Status                        qw( :constants );
use Test::XT::PSGI;
use Plack::Test;
use HTTP::Request::Common;


sub startup : Test( startup => no_plan ) {
    my $self    = shift;
    $self->SUPER::startup;

    $self->{psgi} = Test::XT::PSGI->new();
}


=head1 TESTS

=head2 test_credit_hold_check_accept_order

The following Left Hand Menu Options on the Order View page:
    Credit Hold
    Credit Check
    Accept Order

Had their URLs made Authorative instead of being Dynamic based on how the Operator
arrived at the page. This was done for the XT Access Controls project but the old
links still needed to be protected because the link they use 'ChangeOrderStatus' is
still being used for Cancelling an Order and so the links for the above actions
needed to be re-written to use the Authorative links and therefore be protected
by the ACL Controls.

TODO: Remove this test and the Re-Writes once 'Cancel Order' has been ACL protected.

=cut

sub test_credit_hold_check_accept_order : Tests() {
    my $self = shift;

    my $request_url  = '/CustomerCare/OrderSearch';
    my $response_url = '/Finance/Order';
    my $qry_string   = "order_id=43531";

    my %tests = (
        'Credit Hold - ChangeOrderStatus?action=Hold' => {
            url => "${request_url}/ChangeOrderStatus?${qry_string}&action=Hold",
            expect => {
                url    => "${response_url}/CreditHold?${qry_string}&action=Hold",
                status => HTTP_TEMPORARY_REDIRECT,
            },
        },
        'Credit Check - ChangeOrderStatus?action=Check' => {
            url => "${request_url}/ChangeOrderStatus?${qry_string}&action=Check",
            expect => {
                url    => "${response_url}/CreditCheck?${qry_string}&action=Check",
                status => HTTP_TEMPORARY_REDIRECT,
            },
        },
        'Accept Order - ChangeOrderStatus?action=Accept' => {
            url => "${request_url}/ChangeOrderStatus?${qry_string}&action=Accept",
            expect => {
                url    => "${response_url}/Accept?${qry_string}&action=Accept",
                status => HTTP_TEMPORARY_REDIRECT,
            },
        },
    );

    my %straight_to_login = (
        'Cancel Order - ChangeOrderStatus?action=Cancel, should just go to /Login' => {
            url => "${request_url}/ChangeOrderStatus?${qry_string}&action=Cancel",
            expect => {
                # as there will be no session should go to /Login page
                status => HTTP_OK,
            },
        },
    );

    note "checking deprecated '/.*/.*/ChangeOrderStatus' URL";

    test_psgi $self->{psgi}->app, sub {
            my $cb = shift;

            foreach my $label ( keys %tests ) {
                note "Testing: ${label}";
                my $test   = $tests{ $label };
                my $expect = $test->{expect};

                my $res = $cb->( GET $test->{url} );

                cmp_ok( $res->code, '==', $expect->{status}, "HTTP Status Code returned as Expected" );
                like( $res->header('Location'), qr/\Q$expect->{url}\E/i, "'Location' Header as Expected" );
            }

            foreach my $label ( keys %straight_to_login ) {
                note "Testing: ${label}";
                my $test   = $straight_to_login{ $label };
                my $expect = $test->{expect};

                my $res = $cb->( GET $test->{url} );
                cmp_ok( $res->code, '==', $expect->{status}, "HTTP Status Code returned as Expected" );
                ok( $res->as_string =~ m{loginForm}, "Login page correctly displayed" );
            }

        };
}

Test::Class->runtests;
