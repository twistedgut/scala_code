package Test::XT::Address;
use NAP::policy 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::Address

=head1 DESCRIPTION

Tests the XT::Address class.

=cut

use Test::XTracker::Data;

=head1 TESTS

=head2 startup

Check the class can be used OK.

=cut

sub startup : Tests( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup();

    use_ok('XT::Address');

    $self->{schema} = Test::XTracker::Data->get_schema();

}

=head2 setup

Starts a transaction and creates an Order Address.

=cut

sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup();

    $self->{schema}->txn_begin;

    $self->{order_address} = Test::XTracker::Data
        ->create_order_address_in('current_dc')
        ->discard_changes;

}

=head2 teardown

Rolls back a transaction.

=cut

sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown();

    $self->{schema}->txn_rollback;

}

=head2 test_instantiation

Checks the object can be instantiated OK.

=cut

sub test_instantiation : Tests {
    my $self = shift;

    my $order_address   = $self->{order_address};
    my $address         = $self->new_object_ok;

    address_fields_ok( $address, $order_address->result_source->columns );

    can_ok( $address, qw(
        add_field
        set_field
        get_field
        remove_field
        as_hash
        field_exists
    ) );

}

=head2 test_add_field

Tests the C<add_field> method.

=cut

sub test_add_field : Tests {
    my $self = shift;

    my $address = $self->new_object_ok;

    address_fields_ok( $address, $self->{order_address}->result_source->columns );
    $address->add_field( test_field => 'test_value' );
    address_fields_ok( $address, $self->{order_address}->result_source->columns, 'test_field' );
    cmp_ok( $address->get_field('test_field'), 'eq', 'test_value', 'The field "test_field" returns "test_value"' );

}

=head2 test_remove_field

Tests the C<remove_field> method.

=cut

sub test_remove_field : Tests {
    my $self = shift;

    my $address = $self->new_object_ok;
    my @columns = $self->{order_address}->result_source->columns;

    address_fields_ok( $address, @columns );

    my $removed_column = shift @columns;

    $address->remove_field( $removed_column );
    address_fields_ok( $address, @columns );

    ok( !$address->field_exists( $removed_column ), "The field '$removed_column' has been removed" );

}

=head2 test_apply_format

Tests the C<apply_format> method, by using the two formatters declared in the
L<CLASSES> section below.

=cut

sub test_apply_format : Tests {
    my $self = shift;

    my $address = $self->new_object_ok;
    my @columns = $self->{order_address}->result_source->columns;

    address_fields_ok( $address, @columns );

    ok( !$address->field_exists( 'test_field_one' ), 'The "test_field_one" field does not yet exist' );
    ok( !$address->field_exists( 'test_field_two' ), 'The "test_field_two" field does not yet exist' );

    $address->apply_format('AddTestOne');

    address_fields_ok( $address, @columns, 'test_field_one' );
    cmp_ok( $address->get_field('test_field_one'), 'eq', 'Test Field One', 'test_field_one returns "Test Field One"' );
    ok( !$address->field_exists( 'test_field_two' ), 'The "test_field_two" field does not yet exist' );

    $address->apply_format('AddTestTwo');

    address_fields_ok( $address, @columns, 'test_field_one', 'test_field_two' );
    cmp_ok( $address->get_field('test_field_two'), 'eq', 'Test Field Two', 'test_field_two returns "Test Field Two"' );

}

=head2 test_as_hash

Tests the C<as_hash> method.

=cut

sub test_as_hash : Tests {
    my $self = shift;

    my $address = $self->new_object_ok;
    my @columns = $self->{order_address}->result_source->columns;

    $address->add_field( test_column => 'Test Value' );

    cmp_deeply( { $address->as_hash },
        { $self->{order_address}->get_inflated_columns, test_column => 'Test Value' },
        'The "as_hash" method returns the correct data' );

    cmp_deeply( $address->as_hashref,
        { $self->{order_address}->get_inflated_columns, test_column => 'Test Value' },
        'The "as_hashref" method returns the correct data' );

}

=head1 METHODS

=head2 new_object_ok

Returns a new L<XT::Address> object.

=cut

sub new_object_ok {
    my $self = shift;

    return new_ok( 'XT::Address' => [ $self->{order_address} ] );

}

=head2 address_fields_ok( $address, @expected )

Tests that all the C<@expected> fields are present in the C<$address>.

=cut

sub address_fields_ok {
    my ( $address, @expected ) = @_;

    ok( $address->field_exists( $_ ), "Field '$_' is present" )
        foreach @expected;

}

=head1 CLASSES

=head2 XT::Address::Format::AddTestOne

A dummy formatter class for use in testing, that adds a single field called
'test_field_one' with the value 'Test Field One'.

=cut

BEGIN {

    package XT::Address::Format::AddTestOne;
    use NAP::policy 'class';

    extends 'XT::Address::Format';

    sub APPLY_FORMAT {
        my $self = shift;

        $self->address->add_field( test_field_one => 'Test Field One' );

    }

}

=head2 XT::Address::Format::AddTestTwo

A dummy formatter class for use in testing, that adds a single field called
'test_field_two' with the value 'Test Field Two'.

=cut

BEGIN {

    package XT::Address::Format::AddTestTwo;
    use NAP::policy 'class';

    extends 'XT::Address::Format';

    sub APPLY_FORMAT {
        my $self = shift;

        $self->address->add_field( test_field_two => 'Test Field Two' );

    }

}
