package XT::Rules::Solve;

use strict;
use warnings;
use Carp qw/croak/;
use Moose::Util::TypeConstraints qw/find_type_constraint/;
use XTracker::Config::Local qw( config_var );
use XT::Rules::Definitions;
use XT::Rules::Hash;
use XT::Rules::Situation;
use XT::Rules::Type;

sub solve {
    my ( $class, $rule_name, $execution_args, $solved ) = @_;

    my $rule = eval { $class->lookup( $rule_name ) } ||
        croak "Can't find rule [$rule_name]";

    return $class->execute({
        name            => $rule_name,
        rule_definition => $rule,
        execution_args  => $execution_args || {},
        solved          => $solved,
    });
}

sub lookup {
    my ( $class, $rule_name ) = @_;

    # This should do something more clever soon
    my $rule = $XT::Rules::Definitions::rules{ $rule_name };

    return $rule;
}

sub execute {
    my ( $class, $parameters ) = @_;
    my ( $name, $rule_definition, $execution_args, $solved ) =
        @{$parameters}{qw( name rule_definition execution_args solved )};

    my $type = $rule_definition->{'type'}
        || croak "Rules must have a type defined";

    # Grab the environment - ie: what configuration rules use to access
    # configuration data...
    my $environment = $class->environment( $execution_args );

    # Check and create the situation. This will return a read-only hash-ref
    # with no blessed values, that throws a fatal error if you try to access a
    # non-existant key.
    my $situation = eval { XT::Rules::Situation->generate({
        definition     => $rule_definition->{'situation'},
        execution_args => $execution_args,
        strict         => $type eq 'business' ? 1 : 0
    }) }; croak "Failed to create situation for [$name]: $@" if $@;

    # Resolve the configuration rules. Returns a hash-ref like the above.
    my $configuration = eval { $class->configuration_rules({
        configuration_rules => $rule_definition->{'configuration'},
        execution_args      => $execution_args,
        environment         => $environment,
        solved              => $solved
    }) }; croak "Failed to create configuration for [$name]: $@" if $@;

    # Execute the rule itself
    my $result = eval {
        $rule_definition->{'body'}->(
            $situation,
            $configuration,
            ( $type eq 'configuration' ? ( $environment ) : () )
        )
    }; croak "Failed to execute rule body for [$name]: $@" if $@;

    # The right type?
    my $qualified_constraint_name = 'XT::Rules::Type::' .
        $rule_definition->{'output'};
    my $constraint = (
        find_type_constraint( $rule_definition->{'output'} ) ||
        find_type_constraint( $qualified_constraint_name )
    ) ||
        croak "Can't find a constraint called [" . $rule_definition->{'output'} .
            "] or [$qualified_constraint_name] while solving [$name]";

    # Docs say:
    # validate() is similar to check. However, if the type is valid then the
    # method returns an explicit undef. If the type is not valid, we call
    # $self->get_message($value) internally to generate an error message.
    if ( my $msg = $constraint->validate( $result ) ) {
        croak "Result from [$name] doesn't match required type: $msg";
    }

    return $result;
}

sub environment {
    my ( $class, $execution_args ) = @_;

    # Try for an existing environment
    my $environment = delete $execution_args->{'-environment'};
    return $environment if $environment;

    # Try for a schema
    my $schema = delete $execution_args->{'-schema'};
    croak "You probably meant '-schema', not 'schema'"
        if delete $execution_args->{'schema'};

    unless ($schema) {
        $schema = bless {}, 'XT::Rules::Solve::FakeSchema';
    }

    my %environment;
    $environment{'schema'} = $schema;
    $environment{'config_var'} = sub { return config_var(@_) };

    return \%environment;
}

sub configuration_rules {
    my ( $class, $parameters ) = @_;
    my ( $rules, $execution_args, $environment, $solved ) =
        @{$parameters}{qw( configuration_rules execution_args environment
            solved )};
    $solved ||= {};

    my %results;

    for my $rule_name ( @$rules ) {
        $results{ $rule_name }
            = exists $solved->{$rule_name}
            ? $solved->{$rule_name}
            : $class->solve(
                $rule_name => {
                    -environment => $environment,
                    %$execution_args
                }
            );
    }

    my %return_hash;
    tie %return_hash, 'XT::Rules::Hash', \%results;

    return \%return_hash;

}

sub XT::Rules::Solve::FakeSchema::resultset {
    croak "No -schema was specified for solving the rule, but either the rule" .
        " or subrule requires it"
}

1;
