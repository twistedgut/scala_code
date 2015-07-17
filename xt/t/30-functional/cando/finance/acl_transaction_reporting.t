#!/usr/bin/env perl
use NAP::policy qw( tt class test );

BEGIN {
    extends "NAP::Test::Class";
}

use Test::XT::Flow;
use Test::XTracker::Mechanize;
=head1 NAME

transaction_reporting.t

=head1 DESCRIPTION

Currently only verifies the access restrictions of the [Finance > Transaction
Reporting] page.

=head1 TESTS

=head2 startup

Initialise framework

=cut

sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Finance',
        ],
    );

}

=head2 test__check_transaction_reporting_page

Test the ACL protection on the /Finance/TransactionReporting page.

=cut

sub test__check_transaction_reporting_page : Tests() {
    my $self = shift;

    my $framework = $self->{framework};

    note 'Logging in with no roles or department ..';

    $framework->login_with_roles( { dept => undef } );

    note 'Accessing the /Finance/TransactionReporting page with no roles';

    $framework->catch_error(
        qr/don't have permission to/i,
        q{Can't access the /Finance/TransactionReporting page},
        flow_mech__finance__transaction_reporting => ()
    );

    note 'Accessing the /Finance/TransactionReporting page WITH roles';

    $framework->{mech}->set_session_roles( '/Finance/TransactionReporting' );

    $framework->flow_mech__finance__transaction_reporting;
    $framework->{mech}->no_feedback_error_ok;

}

Test::Class->runtests;
