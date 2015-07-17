#!/usr/bin/env perl
use NAP::policy qw( tt class test );

BEGIN {
    extends "NAP::Test::Class";
}

=head1 NAME

pending_invoices.t

=head1 DESCRIPTION

Currently only verifies the access restrictions of the [Finance > Pending
Invoices] page.

=head1 TESTS

=head2 test__startup_01

Make sure we can load all the required classes.

=cut

sub test__startup_01 : Test( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup;

    use_ok 'Test::XT::Flow';
    use_ok 'Test::XTracker::Data';

}

=head2 test__startup_02

Initialise the Framework.

=cut

sub test__startup_02 : Test( startup => no_plan ) {
    my $self = shift;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Finance',
        ],
    );

}

=head2 test__check_acl_protection

Test the ACL protection on the /Finance/PendingInvoices page.

Steps:
    1. Accessing the page without any roles assigned, should fail.
    2. Accessing the page after assigning the required roles, should succeed.

=cut

sub test__check_acl_protection : Tests() {
    my $self = shift;

    my $framework = $self->{framework};

    note 'Logging in with no roles or department ..';

    # start with NO Roles
    $framework->login_with_roles( {
        # make sure Department is 'undef' as it
        # shouldn't be required for this page
        dept => undef,
    } );

    note 'Accessing the /Finance/PendingInvoices page with no roles should fail ..';

    $framework->catch_error(
        qr/don't have permission to/i,
        q{Can't access the /Finance/PendingInvoices page},
        flow_mech__finance__pending_invoices => ()
    );

    note 'Setting the roles in the session ..';

    $framework->{mech}->set_session_roles( '/Finance/PendingInvoices' );

    note 'Now accessing the page should succeed ..';

    $framework->flow_mech__finance__pending_invoices;
    $framework->{mech}->no_feedback_error_ok;

}

Test::Class->runtests;
