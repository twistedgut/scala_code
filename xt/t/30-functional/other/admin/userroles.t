#!/usr/bin/env perl

use NAP::policy "tt", qw( test );

use Test::XT::Flow;

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Admin',
    ]
);

$flow->login_with_permissions();

my $page = $flow->flow_mech__admin__userroles;

my $roles = [ qw/ app_can_see_dead_people app_can_make_tea / ];

foreach my $role ( @{ $page->mech->as_data->{available_roles} } ) {
    push @$roles, lc $role->{value};
}

$flow->errors_are_fatal(0);
$flow->flow_mech__admin__userroles_update_roles( [ 'invalid_role' ] );
$flow->mech->has_feedback_error_ok( 'Cannot update roles. These roles are not valid: invalid_role' );

$flow->errors_are_fatal(1);
$flow->flow_mech__admin__userroles_update_roles( $roles );

$flow->mech->has_feedback_success_ok(qr/Roles Updated/ );

$page = $flow->flow_mech__admin__userroles;

my $newroles = [];
foreach my $role ( @{ $page->mech->as_data->{new_roles} } ) {
    push @$newroles, $role->{value} if defined $role->{value};
}

cmp_bag( $roles, $newroles, "New roles are the same as submitted" );

done_testing();
