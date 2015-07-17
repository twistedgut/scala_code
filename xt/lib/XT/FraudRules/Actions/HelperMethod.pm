package XT::FraudRules::Actions::HelperMethod;
use NAP::policy "tt", 'class';

=head1 NAME

XT::FraudRules::Actions::HelperMethod

=head1 DESCRIPTION

Provides a simple way to execute arbritrary chained methods, defined in a
string expression, on a DBIx::Class ResultSet object. Returning the final
ResultSet.

The string expression is compiled and executed separately, allowing you to
validate expressions stored in the database before running them.

=head1 SYSNOPSIS

    my $helper_method = XT::FraudRules::Actions::HelperMethod->new(
        schema  => $schema,
    );

    my $success = $helper_method->compile(
        'Public::Country->search( { id => { '!=' => 0 } } )'
    );

    if ( $success ) {

        my $results = $helper_method->execute;

        foreach my $row ( $results->next ) {

            # ...

        }

    }

=head2 ATTRIBUTES

=head2 schema

DBIx::Class Schema Object

This attribute is required.

=cut

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);

=head2 expression

The current expression.

Syntax of the expression is:

object[->method[->method,..]]

Where object is a DBIx::Class ResultSet and method is any valid
method on the object.

=cut

has 'expression' => (
    is  => 'rw',
    isa => 'Str',
);

has 'last_error' => (
    is  => 'rw',
    isa => 'Str',
);

has '_compiled_sub' => (
    is      => 'rw',
    isa     => 'CodeRef|Undef',
    default => undef,
);

has '_object_cache' => (
    is      => 'rw',
    isa     => 'HashRef[Object]',
    default => sub { {} },
);

=head1 METHODS

=head2 compile( $expression )

Compile an expression. If C<$expression> is ommited, the current expression
will be used.

    # These are both equivilent:

    $helper_method->compile( 'Public::Country->first->country' );

    $helper_method->expression( 'Public::Country->first->country' );
    $helper_method->compile;

=cut

sub compile {
    my ( $self, $expression ) = @_;

    # Remove the compiled code reference.
    $self->_compiled_sub( undef );

    # Store the expression in the object, regardless of whether it
    # compiles sor not.
    $self->expression( $expression )
        if $expression;

    if ( $self->expression =~ /^([\w:]+?)(?:->(.+))?$/ ) {
    # If the expression looks OK (it has at least one '->' present).

        # The DBIx::Class Resultset is on the left hand side and
        # the methods to call are on the right.
        my $object_name = $1;
        my $methods     = $2;

        unless ( defined $self->_object_cache->{ $object_name } ) {
        # If this object has not been sen before.
            my $err;
            try {
            # Try to get a ResultSet with that name and store it in
            # the cache.

                $self->_object_cache->{ $object_name } =
                    $self->schema->resultset( $object_name );
                $err=0;
            }

            catch {
            # If we cannot load the ResultSet for any reason, warn
            # about the errors and return false.

                $self->last_error( "Cannot load object '$object_name' due to error $_" );
                $err=1;
            };
            return 0 if $err;

        }

        # We wrap the code in an anonymous subroutine for two reasons:
        #   To check that it compiles and not actually run it yet.
        #   To have a handy CodeRef to call later.
        #   We use the expression form of "eval" here because:
        #       1. $object will ONLY be a ResultSet object.
        #       2. $methods is from a table that has no public interface.
        my $object = $self->_object_cache->{ $object_name };
        my $sub = eval( "sub{ \$object" . ( $methods ? "->$methods" : '' ) ." }" ); ## no critic(ProhibitStringyEval)

        if ( my $error = $@ ) {
        # If compilation failed, warn about any errors and return false.

            $self->last_error( "Compilation failed for expression [$expression] with error $error" );
            return 0;

        }

        # If we have succeeded, store the CodeRef and return true.
        $self->_compiled_sub( $sub );
        return 1;

    } else {

        $self->last_error( "Invalid expression [$expression]" );
        return 0;

    }

    return;

}

=head2 execute

Execute the currently compiled expression, return the result on success
and undef on failure (or no currently compiled expression).

    my $result = $helper_method->execute;

=cut

sub execute {
    my $self = shift;

    if ( my $sub = $self->_compiled_sub ) {
    # If the code has previously been compiled.

        return try {

            # Try calling the previously compiled subroutine reference.
            return $sub->();

        }

        catch {
        # If it failed, warn and return undef.

            $self->last_error( 'Execution failed for expression [' . $self->expression . "] with error $_" );
            return;

        };

    }

    return;

}

1;

