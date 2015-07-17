package Test::XT::Address::Format::Country;
use NAP::policy 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::Address::Format::Country

=head1 DESCRIPTION

Tests the XT::Address::Format::Country class.

=cut

use Test::XTracker::Data;
use Test::MockModule;

=head1 TESTS

=head2 startup

Run once before all tests.

Check we can load all the classes we need and set up shared data.

=cut

sub startup : Tests( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    use_ok('XT::Address');
    use_ok('XT::Address::Format::Country');

    $self->{schema}         = Test::XTracker::Data->get_schema();
    $self->{order_address}  = Test::XTracker::Data->create_order_address_in('current_dc')->discard_changes;
    $self->{country}        = $self->{schema}->resultset('Public::Country')->find({ code => 'DE' });
    $self->{config_name}    = 'PaymentAddressFormatForCountry';

    $self->{order_address}->update({
        country => $self->{country}->country,
    });

}

=head2 setup

Run before each test.

Begins a transaction.

=cut

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->{schema}->txn_begin;

}

=head2 teardown

Run after each test.

Rolls back the transaction.

=cut

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->{schema}->txn_rollback;

}

=head2 test_APPLY_FORMAT_single

Test that only one format is applied when there is only one entry in the
System Config.

=cut

sub test_APPLY_FORMAT_single : Tests {
    my $self = shift;

    my $xt_address      = new_ok( 'XT::Address' => [ $self->{order_address} ] );
    my $format_country  = new_ok( 'XT::Address::Format::Country' => [{ address => $xt_address }] );
    my $mocked          = $self->mock_xt_address_apply_format();

    $self->apply_group_settings( 'TestFormatOne' );
    $format_country->APPLY_FORMAT;

    cmp_deeply( $xt_address->__formats_applied,
        [ 'TestFormatOne' ],
        'Format "TestFormatOne" has been applied' );

}

=head2 test_APPLY_FORMAT_multiple

Test that two formats are applied when there are two entries in the System
Config.

=cut

sub test_APPLY_FORMAT_multiple : Tests {
    my $self = shift;

    my $xt_address      = new_ok( 'XT::Address' => [ $self->{order_address} ] );
    my $format_country  = new_ok( 'XT::Address::Format::Country' => [{ address => $xt_address }] );
    my $mocked          = $self->mock_xt_address_apply_format();

    $self->apply_group_settings( 'TestFormatOne', 'TestFormatTwo' );
    $format_country->APPLY_FORMAT;

    cmp_deeply( $xt_address->__formats_applied,
        [ 'TestFormatOne','TestFormatTwo' ],
        'Format "TestFormatOne" and "TestFormatTwo" have been applied' );

}

=head1 METHODS

=head2 mock_xt_address_apply_format

Mocks the C<apply_format> method in the L<XT::Address> class, so that it only
records the format each time it's called. An additional method is also
created on the L<XT::Address> object that returns the list of calls made to the
C<apply_format> method.

Returns the L<Test::MockModule> object, so the methods can be automatically
restored when it goes out of scope.

=cut

sub mock_xt_address_apply_format {
    my $self = shift;

    my @formats_applied;
    my $module = Test::MockModule->new('XT::Address');

    $module->mock( apply_format => sub { push @formats_applied, $_[1] } );
    $module->mock( __formats_applied => sub { return \@formats_applied } );

    return $module;

}

=head2 apply_group_settings( @formats )

Removes the System Config group "PaymentAddressFormatForCountry", then
recreates it and adds all the requested C<@formats>. The sequence is also
incremented for each entry in C<@formats>.

=cut

sub apply_group_settings {
    my $self = shift;
    my ( @formats ) = @_;

    my $sequence = 0;
    Test::XTracker::Data->remove_config_group( $self->{config_name} );
    Test::XTracker::Data->create_config_group( $self->{config_name} => {
        settings => [
            map { {
                setting     => $self->{country}->code,
                value       => $_,
                sequence    => $sequence++
            } }
            @formats
        ],
    });

}
