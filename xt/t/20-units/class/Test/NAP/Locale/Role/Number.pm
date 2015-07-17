package Test::NAP::Locale::Role::Number;
use NAP::policy "tt", qw(
    test
);

use parent 'NAP::Test::Class';
use Test::XTracker::Data;

=head1 STARTUP

Create a new English NAP::Locale object using a faked customer record
and logger. Store the number and formatted number used in most tests in
the Test object.

=cut

sub startup : Test( startup => 3 ) {
    my $self = shift;

    use_ok 'Test::MockObject';
    use_ok 'NAP::Locale';

    my $channel = Test::XTracker::Data->get_local_channel;

    # Create customer
    my $customer_id = Test::XTracker::Data->create_test_customer(
        channel_id => $channel->id,
    );

    my $customer = $self->schema->resultset("Public::Customer")->find($customer_id);

    # Instantiate a new NAP::Locale Object, using English and with
    # some fake attributes for testing.
    $self->{nap_locale} = new_ok( 'NAP::Locale' => [
        locale   => 'en',
        customer => $customer,
        logger   => fake_object( 'Log::Log4perl::Logger', 'warn' ),
    ] );

}

sub shut_down : Test(shutdown) {
    my $self = shift;

    # Explicitly delete NAP::Locale object to make it demolish now
    $self->{nap_locale} = undef;
    delete $self->{nap_locale};
}

=head1 TESTS

=head2 test_nothing_passed

Test that the method returns an empty string and a warning is added,
if nothing is passed.

=cut

sub test_nothing_passed : Tests() {
    my $self = shift;

    $self->do_test( {
        expected_result => '',
        expected_warn   => qr/requires a number/,
    } );

}

=head2 test_valid_number

Test that if a valid number is passed, we get the correct formatted
string back and no warnings are logged.

=cut

sub test_valid_number : Tests() {
    my $self = shift;

    $self->do_test( {
        parameters      => [ 1234567.125 ],
        expected_result => '1,234,567.13',
    } );

}

=head2 test_valid_number_with_precision

Test that if a valid number and precision is passed, we get the
correct formatted string back to the requested precision and no
warnings are logged.

=cut

sub test_valid_number_with_precision : Tests() {
    my $self = shift;

    $self->do_test( {
        # We add an additional digit, so we can be sure that the
        # number has been formatted when the precision changes.
        parameters      => [ 1234567.1235, 3 ],
        expected_result => '1,234,567.124',
    } );

}

=head2 test_invalid_number

Test that if an invalid number (in this case it has too many decimal
points) is passed, then whatever was passed in is returned and a
warning is logged.

=cut

sub test_invalid_number : Tests() {
    my $self = shift;

    $self->do_test( {
        parameters      => [ '..1234567.125' ],
        expected_result => '..1234567.125',
        expected_warn   => qr/format_number failed/,
    } );

}

=head2 test_already_formatted_valid_number

If a number is passed in that's already formatted, check it's been
re-formatted correctly and no warnings have been logged.

=cut

sub test_already_formatted_valid_number : Tests() {
    my $self = shift;

    $self->do_test( {
        parameters      => [ '1,234,567.125' ],
        expected_result => '1,234,567.13',
    } );

}

=head2 test_already_formatted_invalid_number

If an invalid number is passed in that's already formatted, it should
return whatever was passed in and log a warning, as invalid numbers
cannot be formatted.

=cut

sub test_already_formatted_invalid_number : Tests() {
    my $self = shift;

    $self->do_test( {
        parameters      => [ '..1,234,567.125' ],
        expected_result => '..1,234,567.125',
        expected_warn   => qr/format_number failed/,
    } );

}

=head2 test_non_numeric_parameter

If nothing numeric is passed in, it should return whatever was passed in
and log a warning.

=cut

sub test_non_numeric_parameter : Tests() {
    my $self = shift;

    $self->do_test( {
        parameters      => [ "NON NUMERIC" ],
        expected_result => "NON NUMERIC",
        expected_warn   => qr/number does not contain anything numeric/,
    } );

}

=head2 test_another_locale_fr

Make sure it formats correctly when using another locale. Specifically a
locale that uses completely different thousand/decimal seperators.

=cut

sub test_another_locale_fr : Tests() {
    my $self = shift;

    $self->do_test( {
        locale          => 'fr',
        parameters      => [ 1234567.125 ],
        expected_result => '1 234 567,13',
    } );

}

=head2 test_another_locale_de

Make sure it formats correctly when using another locale. Specifically a
locale that uses inverted thousand/decimal seperators.

=cut

sub test_another_locale_de : Tests() {
    my $self = shift;

    $self->do_test( {
        locale          => 'de',
        parameters      => [ 1234567.125 ],
        expected_result => '1.234.567,13',
    } );

}

=head2 test_already_formatted_valid_number_another_locale

If a number is passed in that's already formatted using the locale 'en' to
a NAP::Local object set to 'de', check it's been re-formatted correctly and
no warnings have been logged.

=cut

sub test_already_formatted_valid_number_another_locale : Tests() {
    my $self = shift;

    $self->do_test( {
        locale          => 'de',
        parameters      => [ '1,234,567.125' ],
        expected_result => '1.234.567,13',
    } );

}

=head1 HELPER METHODS

=head2 do_test( $test )

Executes the test. Expects a HashRef.

If the key parameters is provided, this is passed directly to the number
method, if not, nothing is passed. The key should be an ArrayRef.

The key expected_result is required and is what is expected from the number
method.

If the key expected_warn is provided, then we check that the warn method
was called correctly on the logger object and the message is as expected.
It should be a regex.

The key locale can be used to test with a locale other than the default of
'en'.

    $self->do_test( {
        locale          => 'en',
        parameters      => [ '..1234.56' ],
        expected_result => '..1234.56',
        expected_warn   => qr/format_number failed/,
    } );

=cut

sub do_test {
    my ($self,  $test ) = @_;

    my $locale = $self->{nap_locale};
    my $logger = $locale->logger;

    # Clear the mocked object history.
    $logger->clear;

    # If parameters are passed, use them, otherwise use nothing.
    my @parameters = ( exists $test->{parameters} && ref( $test->{parameters} ) eq 'ARRAY' )
        ? @{ $test->{parameters} }
        : ( );

    # If a locale is specified, use it, otherwise assume 'en' as a default.
    $locale->locale(
        exists $test->{locale}
            ? $test->{locale}
            : 'en'
    );

    # Call the method.
    my $result = $locale->number( @parameters );

    # Check the result.
    cmp_ok( $result, 'eq', $test->{expected_result}, "Result is as expected ($test->{expected_result})" );

    if ( exists $test->{expected_warn} ) {
        # If we expect a warning to have been raised, check it looks OK.

        my ( $method, $arguments ) = $logger->next_call;

        ok( defined $method, 'A method has been called on the logger object' );
        cmp_ok( $method || '', 'eq', 'warn', "warn was the last method called" );
        cmp_ok( @$arguments, '==', 2, "warn was called with the expected number of arguments" );
        like( $arguments->[1] || '', $test->{expected_warn}, "warn has the correct message" );

    } else {
        # Otherwise check no warning has been raised.

        ok( ! $logger->called( 'warn' ), 'warn was not called' );

    }

}

=head2 fake_object( $type, @methods )

Returns a Test::MockObject object set to be isa $type and all the @methods
gauranteed to return a true value.

    my $fake = fake_object( 'Some::Class', 'method1', 'method2' );

    # All return true
    $fake->method1;
    $fake->method2;
    $fake->isa('Some::Class');

=cut

sub fake_object {
    my ( $type, @methods ) = @_;

    my $object = Test::MockObject->new;
    $object->set_isa( $type );

    $object->set_true( $_ )
        foreach @methods;

    return $object;

}

