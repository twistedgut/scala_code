package Test::XT::Rules::Situation;

use strict;
use warnings;

# Type-checker for the bits of information a rule needs to be resolved

use Carp qw/croak/;
use Test::XT::Rules::Hash;
use Moose::Util::TypeConstraints qw/find_type_constraint/;

# I am not a constructor of Test::XT::Rules::Situation objects
sub generate {
    my ( $class, $parameters ) = @_;

    my ( $definition, $args, $strict ) =
        @{ $parameters }{qw/definition execution_args strict/};

    # NOTE: As we are working on getting type coercion to work automagically
    # using Moose, the derive code which is another way of doing the same
    # thing will probably be deprecated... commenting until we either change
    # our mind or delete the next block. 7.12.11
#    # Derivation magic...
#    if ( my $derivatives = delete $args->{'-derive'} ) {
#        my $from = shift( @$derivatives );
#
#        for my $derivative ( @$derivatives ) {
#            my $constraint = $class->lookup_constraint( $derivative );
#
#            my $value = eval { $constraint->assert_coerce( $from ) };
#            if ( $@ ) {
#                croak "Can't derive [$derivative] from a [" . ref($from) .
#                    "]: $@";
#            }
#
#            $args->{ $derivative } = $value;
#        }
#    }

    # Take a shallow copy
    my %args = ( %$args );
    my %result;

    # Find each key
    for my $key ( @$definition ) {
        croak "Situation requires a $key" unless exists $args{$key};
        my $value = delete $args{$key};

        # The key should map to a constraint. Try and retrieve that now
        my $constraint = $class->lookup_constraint( $key );

        # Attempt coercion, get upset if we can't
        $constraint->check( $value ) || do {
            $value = eval { $constraint->assert_coerce($value) };
            if ( $@ ) {
                croak "For key [$key]: $@";
            }
        };

        $result{ $key } = $value;
    }

    # Complain about extra keys
    if ( $strict && keys %args ) {
        croak "The following keys were provided, but were not specified: [" .
            (join ', ', keys %args) . ']';
    }

    my %return_hash;
    tie %return_hash, 'Test::XT::Rules::Hash', \%result;

    return \%return_hash;
}

sub lookup_constraint {
    my ( $class, $name ) = @_;
    $name = "Test::XT::Rules::Type::$name";

    my $constraint = find_type_constraint( $name ) ||
        croak "Can't find a Type Constraint called [$name]";

    return $constraint;
}

1;
