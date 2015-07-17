package Test::XT::FraudRules::Actions::HelperMethod;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::FraudRules::Actions::HelperMethod

=head1 SYNOPSIS

Tests all the methods on a new
Test::XT::FraudRules::Actions::HelperMethod object.

=head1 TESTS

=head2 startup

Get the schema, instantiate a new object and get a random ResultSet
name to use in the tests.

=cut

sub startup : Test( startup => 1 ) {
    my $self = shift;
    $self->SUPER::setup;

    use_ok 'Test::XTracker::Data';
    use_ok 'XT::FraudRules::Actions::HelperMethod';

    $self->{schema} = Test::XTracker::Data->get_schema;

    # Instantiate a new object.
    $self->{object} = new_ok( 'XT::FraudRules::Actions::HelperMethod', [
        schema => $self->{schema},
    ] );

    # Get any ResultSet name, we'll just use the first one.
    $self->{valid_resultset}   = ( $self->{schema}->sources )[0];

}

=head2 test_missing_attribute

Make sure we cannot instantiate the object without a schema.

=cut

sub test_missing_attribute : Tests() {
    my $self = shift;

    # Dies when required parameter 'schema' is missing.
    throws_ok(
        sub { XT::FraudRules::Actions::HelperMethod->new },
        qr/Attribute \(schema\) is required/,
        'dies with missing schema attribute'
    );

}

=head2 test_non_existent_resultset

Make sure compilation fails and we get the correct error when we
pass in a ResultSet name that does not exist.

=cut


sub test_non_existent_resultset : Tests() {
    my $self = shift;

    $self->_compile_ok( 'XXX:XXX', 0 );
    $self->_last_error_ok( qr/Cannot load object.+Can't find source for XXX:XXX/ );

}

=head2 test_typo_in_expression

Make sure we get the correct error when there is a typo in the expression.

The expression will always compile, because this kind of typo will not be
picked up until runtime, so make sure execution fails with the correct error.

=cut

sub test_typo_in_expression : Tests() {
    my $self = shift;

    $self->_compile_ok( "$self->{valid_resultset}\->searc( undef )", 1 );
    $self->_execute_ok;
    $self->_last_error_ok(
        qr/Execution failed for expression.+Can't locate object method "searc"/
    );

}

=head2 test_missing_object

Make sure compilation fails and we get the correct error when we
don't pass in an object.

=cut

sub test_missing_object : Tests() {
    my $self = shift;

    $self->_compile_ok( '->some_method', 0 );
    $self->_last_error_ok( qr/Invalid expression \[.+\]/ );

}

=head2 test_no_methods

Make sure we still get a ResultSet object back when we don't proide
any method.

=cut

sub test_no_methods : Tests() {
    my $self = shift;

    $self->_compile_ok( $self->{valid_resultset}, 1 );
    $self->_execute_ok( 1 ),

}

=head2 test_valid_expression

Finally make sure it compiles and executes OK when we give a valid
expression.

=cut

sub test_valid_expression : Tests() {
    my $self = shift;
    my $object = $self->{object};

    $self->_compile_ok( $self->{valid_resultset} . '->search', 1 );
    $self->_execute_ok( 1 ),

}

#### HELPER METHODS ####

sub _compile_ok {
    my ($self,  $expression, $expected ) = @_;

    cmp_ok(
        $self->{object}->compile( $expression ),
        '==',
        $expected,
        "Expresion '$expression' " . ( $expected ? 'compiles' : 'does not compile' ) . ' as expected'
    );

    return;

}

sub _execute_ok {
    my ($self,  $expected_to_pass ) = @_;

    my $result;

    if ( $expected_to_pass ) {

        isa_ok(
            $result = $self->{object}->execute,
            'DBIx::Class::ResultSet',
            'Results of execution'
        );

        my $expected_result_source_name =
            $self->{schema}
            ->resultset( $self->{valid_resultset} )
            ->result_source
            ->source_name;

        cmp_ok(
            $result->result_source->source_name,
            'eq',
            $expected_result_source_name,
            "We got the correct ResultSet - $expected_result_source_name"
        );

        return $result;

     } else {

        ok(
            !defined $self->{object}->execute,
            'Execution failed as expected'
        );

     }

    return;

}

sub _last_error_ok {
    my ($self,  $expected ) = @_;

    like(
        $self->{object}->last_error,
        $expected,
        "We got the correct error - $expected"
    );

}
