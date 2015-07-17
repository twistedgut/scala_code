package Test::XTracker::Role::Metrics;
use NAP::policy qw( test );
use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Role::Metrics

=head1 DESCRIPTION

Test the role L<XTracker::Role::Metrics>

=head1 TESTS

=cut

sub test_class__startup : Test( startup => no_plan) {
    my $self = shift;

    use_ok( 'XTracker::Role::Metrics' );

    $self->{pkg} = Test::XTracker::Role::Metrics::RoleConsumer->new();
    isa_ok( $self->{pkg}, "Test::XTracker::Role::Metrics::RoleConsumer" );

    # Ensure the system configuration is set as we expect
    $self->{setting} = $self->schema->resultset('SystemConfig::ConfigGroupSetting')->search( {
                    'config_group.name' => 'Send_Metrics_to_Graphite',
                    'me.setting'        => 'is_active',
                },
                { join    => 'config_group' }
            )->first;
}

=head2 test_can_send_metrics_method

Tests that the send_metric method works. Note that this is dependant upon the
system configuration hence we mess with it here (in a transaction!)

=cut

sub test_can_send_metric_method : Tests {
    my $self = shift;

    ok( $self->{pkg}->can('send_metric'), "Can call send_metric method" );

    my $setting = $self->{setting};

    # Start a transaction
    $self->schema->txn_begin;
    $setting->update( { value   => 1 } );

    my $sent = $self->{pkg}->send_metric(int(rand(10)+1));
    ok( $sent, "A valid call to send_metric returns true" );

    $sent = $self->{pkg}->send_metric( { and => 'I', can => 'send', a => 'hashref' } );
    ok( $sent, "A valid call to send_metric with a hashref value returns true" );

    $sent = $self->{pkg}->send_metric();
    ok( !$sent, "An invalid call to send_metric returns false" );

    # Rollback the transaction
    $self->schema->txn_rollback;
}

=head2 test_send_metric_when_config_turned_off

Test that when configuration is off calls to send_metric return false

=cut

sub test_send_metric_when_config_turned_off : Tests {
    my $self = shift;

    my $setting = $self->{setting};

    $self->schema->txn_begin;
    $setting->update( { value => 0 } );

    my $sent = $self->{pkg}->send_metric(int(rand(10)));
    ok( ! $sent, "A call to send_metric returns false when configuration is turned off" );

    $self->schema->txn_rollback;
}

=head1 CLASSES

=head2 Test::XTracker::Role::Log::RoleConsumer

A wrapper class that only exists to consume the role L<XTracker::Role::Log> and
nothing else.

=cut

BEGIN {

package Test::XTracker::Role::Metrics::RoleConsumer;
use NAP::policy qw( class );

with 'XTracker::Role::Metrics';

}

