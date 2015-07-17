package Test::XTracker::Schema::Result::Public::Channel;

use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Schema::Result::Public::Channel

=head1 DESCRIPTION

Unit tests for XTracker::Schema::Result::Public::Channel

=cut

use Test::XTracker::Data;


sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;
}

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;
}

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}


=head1 TESTS

=head2 test_get_pre_order_system_config

Tests the 'get_pre_order_system_config' method which should return
all the Pre-Order system config settings.

=cut

sub test_get_pre_order_system_config : Tests() {
    my $self = shift;

    my $channel = Test::XTracker::Data->any_channel;
    my $settings = {
        is_active          => 1,
        can_apply_discount => 1,
        max_discount       => 30,
        discount_increment => 5,
    };
    Test::XTracker::Data->set_pre_order_discount_settings( $channel, $settings );

    my $got = $channel->get_pre_order_system_config;
    cmp_deeply( $got, $settings, "got Expected 'PreOrder' Settings back" );

    # remove the PreOrder Settings Group and check 'undef' comes back
    Test::XTracker::Data->remove_config_group('PreOrder');
    $got = $channel->get_pre_order_system_config;
    ok( !defined $got, "got 'undef' back when there is NO 'PreOrder' Config Settings" )
                    or diag "expected 'undef' but got back: " . p( $got );
}

