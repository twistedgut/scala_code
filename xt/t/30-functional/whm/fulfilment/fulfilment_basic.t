#!/usr/bin/env perl

=head1 NAME

fulfilment_basic.t - Test the fulfilment process. No frills, no odd situations,
just the basic expected process

=head1 DESCRIPTION

Only runs in DC1/DC3. Does what it says on the tin.

Tests the happy path - creates a shipment in code, then through mech it goes
through selection, picking, packing, labelling (if we're in DC1) and dispatch.

#TAGS fulfilment selection picking packing labelling dispatch iws prl whm

=cut

use NAP::policy "tt", 'test';
use Test::XTracker::RunCondition dc => [ qw/DC1 DC3/];
use Test::XT::Flow;
use XTracker::Constants::FromDB qw( :authorisation_level );

# Init framework and login
my $framework = Test::XT::Flow->new_with_traits( traits => [ 'Test::XT::Flow::Fulfilment' ] );
$framework->login_with_permissions({
    perms => { $AUTHORISATION_LEVEL__MANAGER => [
        'Fulfilment/Selection',
        'Fulfilment/Picking',
        'Fulfilment/Packing',
        'Fulfilment/Labelling',
        'Fulfilment/Dispatch',
    ]},
    dept => 'Customer Care',
});

# Go through the whole process
$framework->task__dispatch();

done_testing();
