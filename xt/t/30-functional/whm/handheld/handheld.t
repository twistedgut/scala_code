#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

handheld.t - Test handheld basics: Menu format, login, logout, etc.

=head1 DESCRIPTION

Verify that a user with no permissions is prevented from accessing anything.

For a normal user, verify the correct menu items appear in different rollout
phases.

#TAGS http prl iws intermittentfailure whm

=cut

use FindBin::libs;
use Test::XTracker::RunCondition(
    export => [ qw( $iws_rollout_phase $prl_rollout_phase ) ],
);

use XTracker::Constants::FromDB ':authorisation_level';

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use Data::Dump  qw( pp );

my $mech    = Test::XTracker::Mechanize->new;
my $schema  = Test::XTracker::Data->get_schema;

#just grant any old permissions to get the user enabled
Test::XTracker::Data->grant_permissions('it.god', 'Customer Care', 'Order Search', $AUTHORISATION_LEVEL__OPERATOR);

Test::XTracker::Data->set_department('it.god', 'Shipping');

$mech->handheld_login_ok('it.god', 'it.god');

my $operator    = Test::XTracker::Data->_get_operator( 'it.god' );

# a list of menu items that should be on the Hand Held main menu
# along with their section and sub-section's for setting permissions
# TODO: DCA-1726: Really Remove stock control/cancellations page
my @cancellation_putaway_menu_item = $prl_rollout_phase
    ? ()
    : ( [ ['Cancellation Put Away'] => [
            'Stock Control',
            'Cancellations',
        ] ] );
my @menu_items  = (
    ( $iws_rollout_phase < 1 ? (
        [ ['Picking',1]                 => [ 'Fulfilment', 'Picking' ] ],
    ):()),
    ( $prl_rollout_phase ? (
        [ ['Induction']                 => [ 'Fulfilment', 'Induction' ] ],
    ):()),
    [ ['Dispatch']                  => [ 'Fulfilment', 'Dispatch' ] ],
    [ ['Put Away']                  => [ 'Goods In', 'Putaway' ] ],
    [ ['Returns Arrivals']          => [ 'Goods In', 'Returns Arrival' ] ],
    [ ['Location Stock Check']      => [ 'Stock Control', 'Stock Check' ] ],
    [ ['Product Stock Check']       => [ 'Stock Control', 'Stock Check' ] ],
    [ ['Move Stock']                => [ 'Stock Control', 'Inventory' ] ],
    ( $iws_rollout_phase < 1 ? (
        [ ['Stock Relocation']          => [ 'Stock Control', 'Stock Relocation' ] ],
        [ ['Auto Stock Count']          => [ 'Stock Control', 'Perpetual Inventory' ] ],
        [ ['Manual Stock Count']        => [ 'Stock Control', 'Perpetual Inventory' ] ],
        [ ['Picking',2]                 => [ 'Stock Control', 'Channel Transfer' ] ],
        [ ['Putaway']                   => [ 'Stock Control', 'Channel Transfer' ] ],
        @cancellation_putaway_menu_item,
    ):())
);
my $first_flag = 1;

note "TESTING Hand Held Menu";

# clear all permissions for operator
$operator->permissions->delete;

foreach my $item ( @menu_items ) {

    my $menu_option = $item->[0][0];
    note "Menu Option: $menu_option";

    if ( $first_flag ) {
        note "Test No Permissions for First Option Only";

        $mech->follow_link_ok({
            text => $menu_option,
            ( @{$item->[0]} > 1 ? ( n => $item->[0][1] ) : () )
        },"Goto -> $menu_option");
        $mech->has_feedback_error_ok( qr/You don't have permission to access/ )
            or diag(
                $mech->content,
                # This test fails sometimes:
                # If these 2 differ then probably should use '->discard_changes'
                # when deleting permissions above, but just testing a theory.
                # If they both have a value then the delete didn't work or something
                # else is creating permissions after they have been deleted
                "\nPermission Count No Discard Changes  : " . $operator->permissions->count,
                "\nPermission Count With Discard Changes: " . $operator->discard_changes->permissions->count
            );
        $mech->content_contains( 'body class="handheld"', "Page in Hand Held mode" );

        # set permissions for all of the menu options
        foreach my $perm ( @menu_items ) {
            note "granting @{$perm->[1]}";
            Test::XTracker::Data->grant_permissions('it.god', @{$perm->[1]}, 2 );
        }
        $mech->follow_link_ok({ url => '/HandHeld/Home' }, 'Display Hand Held Menu' );
        $mech->no_feedback_error_ok;

        $first_flag = 0;
    }

    $mech->follow_link_ok({
            text => $menu_option,
            ( @{$item->[0]} > 1 ? ( n => $item->[0][1] ) : () )
        },"Goto -> $menu_option");
    $mech->no_feedback_error_ok;
    $mech->content_contains( 'body class="handheld"', "$menu_option Page in Hand Held mode" );

    # back to main menu
    $mech->follow_link_ok({ url => '/HandHeld/Home' }, 'Display Hand Held Menu' );
    $mech->no_feedback_error_ok;
    $mech->content_contains( 'body class="handheld"', "Page in Hand Held mode" );
}

$mech->follow_link_ok({ text_regex => qr/(Logout)/ }, "Logout Link" );
$mech->content_contains( 'body class="handheld"', "Page in Hand Held mode" );

# clear all permissions for operator
$operator->discard_changes;
$operator->permissions->delete;

done_testing;
