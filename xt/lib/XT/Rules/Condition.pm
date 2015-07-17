package XT::Rules::Condition;

use NAP::policy "tt",     qw( class );
with 'XTracker::Role::WithXTLogger';

=head1 NAME

XT::Rules::Condition

=head1 SYNOPSIS

    use XT::Rules::Condition;

    $condition  = XT::Rules::Condition->new( {
        to_evaluate => { ... },     # see below
        objects     => [
            # list of DBIC Objects that
            # the Condition will use
            $dbic_object_1,
            $dbic_object_2,
            ...
        ],

        # this is required for parsing Place Holders and
        # if not passed in will be derived from the first
        # 'channel' or 'get_channel' method it can find from
        # the 'objects' list, if none can be found it will
        # throw an exception
        channel     => $sales_channel_obj,

        # if this is not passed in then it
        # will be derived from 'channel'
        schema      => $schema_obj,

        # optional
        cache   => \%cache_for_methods_and_place_holders
        logger  => $log4perl_obj,
        die_on_error => 1,
    } );

    # then
    $condition->compile;        # Compile the Condition
    $condition->evaluate;       # Evaluate the Condition

    # to get the result
    $condition->has_passed;     # returns TRUE if the Condition PASSED
    $condition->has_failed;     # returns TRUE if the Condition FAILED

    $condition->has_error;      # an error occured and the above 2 will return FALSE
    $condition->error;          # a HashRef containg details about the error

To pass in something that should be evaluated:

    # if only these are passed the Condition will PASS if the 'method_to_call' returns TRUE
    to_evaluate => {
        # these two are ALWAYS required for all uses of 'to_evaluate'
        class   => 'Public::SomeThing',     # class name of an Object in the 'objects' array
        method  => 'method_to_call',        # method name that will be called on the Object

        # optional in all uses of 'to_evaluate'
        params  => '[ 1, {"foo":"bar"} ]',  # a JSON string of paramaters to be passed to 'method'
    },

    # this will PASS the Condition if 'method_to_call' returns FALSE
    to_evaluate => {
        class       => 'Public::SomeThing',
        method      => 'method_to_call',
        operator    => 'boolean',           # 'boolean' operator tells Condition that the output of 'method' will be boolean
        value       => 'false',
    },

    # this will PASS the Condition if value from 'method_to_call' is greater than or equal to '1234.56'
    to_evaluate => {
        class       => 'Public::SomeThing',
        method      => 'method_to_call',
        operator    => '>=',                # a perl operator to compare the output of 'method' with 'value'
        value       => 1234.56,
    },

    # this will PASS the Condition if value from 'method_to_call' is equal to '36'
    to_evaluate => {
        class       => 'Public::SomeThing',
        method      => 'method_to_call',
        operator    => '==',
        value       => '34 + 2',
        eval_value  => 1,                   # using 'eval_value' will cause 'value' to be evaluated first
    },


Place Holders:

Within the 'to_evaluate' argument you can pass place holders in the 'params' and/or 'value'
arguments, these will be processed by 'XT::Text::PlaceHolder'.

=head1 DESCRIPTION

Will Evaluate a Condition that has been passed in the 'to_evaluate' argument by calling a method
from one of the list of objects passed into the 'objects' array.

=cut

use XTracker::Utilities         qw( trim );
use XT::Cache::Function         qw( :key );

use XT::Text::PlaceHolder;

use Carp;
use Const::Fast;
use Safe;
use JSON;

# this isn't for DEBUG it's for dumping out Errors
use Data::Dump      qw( pp );

# Constants
const my $BOOLEAN_TRUE  => '_' . __PACKAGE__ . '::TRUE';
const my $BOOLEAN_FALSE => '_' . __PACKAGE__ . '::FALSE';


=head1 ATTRIBUTES

=head2 to_evaluate

This is a Hash Ref that tells the Class what to Evaluate:

    {
        # required
        class   => 'Public::SomeThing',     # class name of an Object in the 'objects' array
        method  => 'method_to_call',        # method name that will be called on the Object

        #
        # optional;
        #

        params  => '[ 1, {"foo":"bar"} ]',  # a JSON string of paramaters to be passed to 'method'

        # if used then both of these are required
        operator    => '==',
        value       => '34 + 2',

        eval_value  => 1,                   # using 'eval_value' will cause 'value' to be evaluated first
    }

The various parts of the above will be transformed using private methods when you call 'compile'.

=cut

has to_evaluate => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => 'to_evaluate',
    required    => 1,
    traits      => ['Hash'],
    handles     => {
        to_evaluate_has_a_value_for => 'defined',
        get_from_to_evaluate        => 'get',
    },
);

=head2 objects

An Array Ref of Objects that will be used in Evaluating the Condition.

=cut

has objects => (
    is          => 'ro',
    isa         => 'ArrayRef[Object]',
    init_arg    => 'objects',
    required    => 1,
    traits      => ['Array'],
    handles     => {
        all_objects     => 'elements',
    },
);

=head2 channel

Required for parsing channelised Place Holders

=cut

has channel => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Channel',
    init_arg    => 'channel',
    required    => 1,
    lazy_build  => 1,
);

=head2 schema

Required for parsing some Place Holders, will be derived
from 'channel' if not provided in 'new()'.

=cut

has schema => (
    is          => 'ro',
    isa         => 'XTracker::Schema',
    lazy_build  => 1,
);

=head2 has_passed

Returns TRUE if the Condition has PASSED

=cut

has has_passed => (
    is      => 'rw',
    isa     => 'Bool',
    init_arg => undef,
    # if this is TRUE then the other 'has_*' attributes must be FALSE
    trigger => sub {
        my $self    = shift;
        return      if ( !$self->has_passed );

        $self->has_failed(0);
        $self->has_error(0);
        return;
    },
);

=head2 has_failed

Returns TRUE if the Condition has FAILED

=cut

has has_failed => (
    is      => 'rw',
    isa     => 'Bool',
    init_arg => undef,
    # if this is TRUE then the other 'has_*' attributes must be FALSE
    trigger => sub {
        my $self    = shift;
        return      if ( !$self->has_failed );

        $self->has_passed(0);
        $self->has_error(0);
        return;
    },
);

=head2 has_error

Returns TRUE if the there has been an Error

=cut

has has_error => (
    is      => 'rw',
    isa     => 'Bool',
    init_arg => undef,
    default => 0,
    # if this is TRUE then the other 'has_*' attributes must be FALSE
    trigger => sub {
        my $self    = shift;
        return      if ( !$self->has_error );

        $self->has_passed(0);
        $self->has_failed(0);
        return;
    },
);

=head2 error

    $hash_ref   = $self->error;

A Hash Ref used to describe any Errors that occur.

=cut

has error => (
    is          => 'rw',
    isa         => 'Maybe[HashRef]',
    init_arg    => undef,
);

=head2 die_on_error

By default an error in Compilation or Evaluation will not throw an exception just
populates '$self->error' and set the 'has_error' flag to be TRUE, if this is set
to TRUE then these attributes will be set AND an Exception will be thrown.

=cut

has die_on_error => (
    is      => 'ro',
    isa     => 'Bool',
    init_arg => 'die_on_error',
    default => 0,
);


# This holds the condition that's been parsed and transformed
# from the original 'to_evaluate' attribute that was passed in
# on construction.
has _parsed_condition => (
    is      => 'rw',
    isa     => 'HashRef',
    init_arg=> undef,
    traits  => ['Hash'],
    handles => {
        _add_to_parsed_condition    => 'set',
    },
);

# cache for Method calls
has _method_cache => (
    is      => 'rw',
    isa     => 'HashRef',
    init_arg=> undef,
    default => sub { return {}; },
    traits  => ['Hash'],
    handles => {
        _add_to_method_cache    => 'set',
        _get_from_method_cache  => 'get',
        _check_method_cache     => 'exists',
    },
);

# cache for Place Holders
has _ph_cache => (
    is      => 'rw',
    isa     => 'HashRef',
    init_arg=> undef,
    default => sub { return {}; },
    traits  => ['Hash'],
    handles => {
        _add_to_ph_cache    => 'set',
        _get_from_ph_cache  => 'get',
        _check_ph_cache     => 'exists',
    },
);

# use JSON to parse the parameters for a Method
has _json => (
    is      => 'ro',
    isa     => 'JSON',
    init_arg => undef,
    lazy_build => 1,
);

# using 'Safe' as a safe way of eval'ing
# operators and values etc.
has _safe_eval => (
    is      => 'ro',
    isa     => 'Safe',
    init_arg => undef,
    lazy    => 1,
    default => sub {
        return Safe->new();
    },
);

# a HashRef containing a list of Opcodes that are
# safe to use for different reasons when eval'ing.
# See the Docs for the 'Opcode' package for more details.
has _safe_opcodes => (
    is      => 'ro',
    isa     => 'HashRef',
    init_arg => undef,
    lazy    => 1,
    default => sub {
        return {
            # for anything to work these are required
            # rv2gv is odd - see
            # http://www.nntp.perl.org/group/perl.perl5.porters/2013/10/msg208561.html
            default => [ qw(
                padany lineseq const leaveeval rv2gv
            ) ],
            # when evaling Operators
            operator => [ qw(
                lt i_lt gt i_gt le i_le ge i_ge eq i_eq ne
                i_ne ncmp i_ncmp slt sgt sle sge seq sne scmp
                pushmark pushre list grepstart not
            ) ],
            # when evaling Values
            value   => [ qw(
                abs pow multiply i_multiply divide i_divide
                modulo i_modulo add i_add subtract i_subtract
            ) ],
            # when evaling a Comparison
            comparison => [ qw(
                rv2sv cond_expr null rv2av scalar
            ) ],
        };
    },
);

has _json_decode_operators => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    traits      => [ 'Hash' ],
    default     => sub {
        return {
            map { $_ => 1 } qw(
                grep
                !grep
            )
        };
    },
    handles     => {
        _json_decode_required   => 'exists',
    },
);

has _in_list_operator => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    traits      => [ 'Hash' ],
    default     => sub {
        return {
            map { $_ => 1 } qw(
                grep
                !grep
            )
        };
    },
    handles     => {
        _is_in_list_operator   => 'exists',
    },
);

# change the BUILD sub to take in a HASH
# and then assign it to the Method and
# Place Holder Caches also handles a Logger
sub BUILD {
    my ( $self, $args ) = @_;

    if ( my $cache = delete $args->{cache} ) {
        $self->_method_cache( $cache->{m} //= {} );
        $self->_ph_cache( $cache->{ph} //= {} );
    }

    if ( my $logger = delete $args->{logger} ) {
        $self->set_xtlogger( $logger );
    }

    return $self;
}


=head1 METHODS

=head2 compile

Compile the Condition that has been passed to be Evaluated in 'to_evalaute'.

=cut

sub compile {
    my $self    = shift;

    $self->_log_debug("Compiling Condition");

    return 0    if ( !$self->_validate );

    # transform the parts of 'to_evaluate'
    # to populate '_parsed_condition' so that
    # the condition can be executed later
    return 0    if (
           !$self->_transform_params
        || !$self->_transform_value
        || !$self->_transform_class
    );

    # generate a key for the Method Cache
    my @key_args    = (
        $self->_parsed_condition->{object},
        $self->_parsed_condition->{method}
    );
    push @key_args, @{ $self->_parsed_condition->{params} }
                        if ( exists( $self->_parsed_condition->{params} ) );
    my $cache_key   = generate_method_cache_key( @key_args );
    $self->_parsed_condition->{cache_key}   = $cache_key;

    return 1;
}

=head2 evaluate

Evaluates the Condition that's been Compiled and sets the
following Attributes to determine if the Condition:

    * has_passed
    * has_failed
    * has_error

=cut

sub evaluate {
    my $self    = shift;

    $self->_log_debug("Evaluating Condition");

    my $object  = $self->_parsed_condition->{object};
    my $method  = $self->_parsed_condition->{method};
    my @params  = @{ $self->_parsed_condition->{params} // [] };
    my $cache_key = $self->_parsed_condition->{cache_key};

    my $result;

    if ( $self->_check_method_cache( $cache_key ) ) {
        $result = $self->_get_from_method_cache( $cache_key );
    }
    else {
        # call the Method on the Object to get a result to compare with
        eval {
            $result = (
                exists( $self->_parsed_condition->{'params'} )
                ? $object->$method( @params )
                : $object->$method
            );
        };
        if ( my $err = $@ ) {
            $self->_failure( {
                stage   => 'Evaluating Condition',
                message => "Couldn't Evaluate the Condition",
                exception => $err,
            } );

            return $self;
        }
        $self->_add_to_method_cache( $cache_key => $result );
    }

    my $value   = $self->_parsed_condition->{value};
    my $operator= $self->_parsed_condition->{operator};

    # now see if the result PASSES the Condition
    my $test_result;
    if ( $operator eq 'boolean' ) {
        # if the Operator was for 'boolean' then
        # just see if the result is TRUE or FALSE
        my $boolean_result  = ( $result ? $BOOLEAN_TRUE : $BOOLEAN_FALSE );
        # now see which Boolean result is
        # the one that passes the condition
        $test_result = ( $value eq $boolean_result ? 1 : 0 );
        $self->_log_debug("Evaluated a 'boolean' Condition");
    }
    else {
        $test_result = $self->_eval_comparison( $result, $operator, $value );
        if ( my $err = $@ ) {
            $self->_failure( {
                stage   => 'Evaluating Condition',
                message => "Couldn't Compare the Result",
                exception => $err,
            } );

            return $self;
        }
        $self->_log_debug("Evaluated a Condition");
    }

    if ( $test_result ) {
        $self->_log_debug("Condition has PASSED");
        $self->has_passed(1);
    }
    else {
        $self->_log_debug("Condition has FAILED");
        $self->has_failed(1);
    }

    return $self;
}


# validate what was passed in 'to_evaluate' is sane
sub _validate {
    my $self    = shift;

    $self->_log_debug("Validating Condition");

    my $stage_for_error = "Validation of 'to_evaluate'";

    #
    # First check if 'to_evaluate' has everything we need
    #

    # must have these fields
    foreach my $key ( qw( class method ) ) {
        if ( !$self->to_evaluate_has_a_value_for( $key ) ) {
            return $self->_failure( {
                stage   => $stage_for_error,
                message => "No defined value for '${key}' found",
            } );
        }
    }

    # if there is a Value then there must also be an Operator
    if ( $self->to_evaluate_has_a_value_for('value')
      && !$self->to_evaluate_has_a_value_for('operator') ) {
        return $self->_failure( {
            stage   => $stage_for_error,
            message => "There is a 'Value' key but no 'Operator' found",
        } );
    }

    #
    # Now check that what has been passed is usable
    #

    # check if the 'class' matches any of the Classes of
    # the Objects passed in to the 'objects' array
    my $class   = $self->get_from_to_evaluate('class');
    if ( !grep { ref( $_ ) =~ /::${class}$/i } $self->all_objects ) {
        return $self->_failure( {
            stage   => $stage_for_error,
            message => "'class' used in 'to_evaluate' does not match any of the Classes in the 'objects' array",
        } );
    }

    # try and evaluate any Parameters passed
    if ( my $params = $self->get_from_to_evaluate('params') ) {
        $params = trim( $params );
        if ( $params !~ /^\[/ || $params !~ /\]$/s ) {
            return $self->_failure( {
                stage   => $stage_for_error,
                message => "Couldn't eval 'params'",
                exception => "Doesn't look it's a JSON Array",
            } );
        }
    }

    # check the 'operator' is valid
    if ( my $operator = $self->get_from_to_evaluate('operator') ) {
        # 'boolean' is handled differently so don't bother checking it
        if ( $operator ne 'boolean' ) {
            if ( $self->_is_in_list_operator($operator) ) {
                my $tmp = $self->_eval_operator( "${operator} " . '{$_ == 1} (1, 2)' );
            }
            else {
                my $tmp = $self->_eval_operator( "1 ${operator} 2" );
            }

            if ( my $err = $@ || $operator eq '#' ) {
                return $self->_failure( {
                    stage   => $stage_for_error,
                    message => "Couldn't eval 'operator'",
                    exception => $err,
                } );
            }
        }
    }

    return 1;
}

# transform the 'params' passed in so
# that they are a proper perl variable
sub _transform_params {
    my $self    = shift;

    # having no 'params' is still fine
    return 1    if ( !$self->to_evaluate_has_a_value_for('params') );

    $self->_log_debug("Transforming Condition's Parameters");

    my $decoded_params  = [];

    my $params  = trim( $self->get_from_to_evaluate('params') );
    if ( $params ) {
        eval {
            $self->_log_debug("Replacing Place Holders for Parameters");
            $params = $self->_replace_place_holders( $params );
        };
        if ( my $err = $@ ) {
            return $self->_failure( {
                stage   => 'Transforming Params',
                message => "Couldn't replace Place Holders",
                exception => $err,
            } );
        }

        # now decode the JSON params, which should always be in an Array - [ ... ]
        eval {
            $decoded_params = $self->_json->decode( $params );
        };
        if ( my $err = $@ ) {
            return $self->_failure( {
                stage   => 'Transforming Params',
                message => "Couldn't decode 'params'",
                exception => $err,
            } );
        }
    }

    $self->_add_to_parsed_condition( params => $decoded_params );

    return 1;
}

# transform the 'value' passed in so
# that they are a proper perl variable
sub _transform_value {
    my $self    = shift;

    $self->_log_debug("Transforming Condition's Value");

    my $value   = $self->get_from_to_evaluate('value');

    if ( $self->to_evaluate_has_a_value_for('value') ) {
        # just store the operator
        my $operator    = $self->get_from_to_evaluate('operator');
        $self->_add_to_parsed_condition( operator => $operator );

        # if the Operator is 'boolean' then work
        # out if the expected Value is TRUE or FALSE
        if ( $operator eq 'boolean' ) {
            $value  = $self->_get_boolean_outcome( $value );
            if ( !$value ) {
                return $self->_failure( {
                    stage   => "Transforming Value",
                    message => "The Operator is 'boolean' but the Value is not an acceptable Boolean",
                } );
            }
        }
        else {
            # it's a non-boolean value replace any
            # place holders if 'value' is not 'undef'
            if ( defined $value ) {
                eval {
                    $self->_log_debug("Replacing Place Holders for Value");
                    $value  = $self->_replace_place_holders( $value );
                };
                if ( my $err = $@ ) {
                    return $self->_failure( {
                        stage   => "Transforming Value",
                        message => "Couldn't replace Place Holders",
                        exception => $err,
                    } );
                }

                # if the 'value' is to be eval'd
                if ( $self->get_from_to_evaluate('eval_value') ) {
                    $value  = $self->_eval_value( $value );
                    if ( my $err = $@ ) {
                        return $self->_failure( {
                            stage   => "Transforming Value",
                            message => "Couldn't 'eval' Value",
                            exception => $err,
                        } );
                    }
                }

                if ( $self->_json_decode_required($operator) ) {
                    eval {
                        $value = $self->_json->decode( $value );
                    };
                    if ( my $err = $@ ) {
                        return $self->_failure( {
                            stage       => "Transforming Value",
                            message     => "Could not 'json decode' value",
                            exception   => $err,
                        } );
                    }
                }
            }
        }
    }
    else {
        # if no value then assume
        # the result should be TRUE
        $value  = $BOOLEAN_TRUE;
        $self->_add_to_parsed_condition( operator => 'boolean' );
    }

    # store the result in '_parsed_condition'
    $self->_add_to_parsed_condition( value => $value );

    return 1;
}

# get the object to use for the 'class'
sub _transform_class {
    my $self    = shift;

    $self->_log_debug("Transforming Condition's Class");

    my $class   = $self->get_from_to_evaluate('class');

    # search all the objects which have a matching class
    my ( $object )  = grep { ref( $_ ) =~ m/\W+${class}$/ } $self->all_objects;

    if ( !$object ) {
        return $self->_failure( {
            stage   => 'Transforming Class',
            message => "Couldn't find an Object with the requested Class Name",
        } );
    }

    my $method  = $self->get_from_to_evaluate('method');
    if ( !$object->can( $method ) ) {
        return $self->_failure( {
            stage   => 'Transforming Class',
            message => "Method doesn't exist on Object",
        } );
    }

    # add both the Object and the name of the Method to call
    $self->_add_to_parsed_condition(
        object => $object,
        method => $method,
    );

    return 1;
}

# replace place holders that could
# be in 'params' or the 'value'
sub _replace_place_holders {
    my ( $self, $string )   = @_;

    my $ph = XT::Text::PlaceHolder->new( {
        string      => $string,
        schema      => $self->schema,
        objects     => $self->objects,
        channel     => $self->channel,
        cache       => $self->_ph_cache,
        logger      => $self->xtlogger,
    } );

    return $ph->replace;
}


#
# the following are used to 'eval'
# various parts of the Condition
#

# use '_safe_eval' to evaluate Operators
sub _eval_operator {
    my ( $self, $to_eval )  = @_;

    my $safe = $self->_safe_eval;

    # permit only the following
    $safe->permit_only(
        @{ $self->_safe_opcodes->{default} },
        @{ $self->_safe_opcodes->{operator} },
        @{ $self->_safe_opcodes->{comparison} },
    );

    return $safe->reval( $to_eval );
}

# use '_safe_eval' to evaluate Values
sub _eval_value {
    my ( $self, $to_eval )  = @_;

    my $safe = $self->_safe_eval;

    # permit only the following
    $safe->permit_only(
        @{ $self->_safe_opcodes->{default} },
        @{ $self->_safe_opcodes->{value} },
    );

    return $safe->reval( $to_eval );
}

# use '_safe_eval' to evaluate a comparison
sub _eval_comparison {
    my ( $self, $left, $operator, $right )  = @_;

    my $safe = $self->_safe_eval;

    # permit only the following
    $safe->permit_only(
        @{ $self->_safe_opcodes->{default} },
        @{ $self->_safe_opcodes->{comparison} },
        @{ $self->_safe_opcodes->{operator} },
    );

    # pass variables into the Safe compartment
    ${ $safe->varglob('left') } = $left;
    ${ $safe->varglob('right') }= $right;

    my $ref_type = ref $right;

    unless ( $ref_type ) {
        return $safe->reval( '( $left ' . $operator . ' $right ? 1 : 0 )' );
    }

    if ( $ref_type eq 'ARRAY' ) {
        return $safe->reval( '( scalar( ' . $operator . ' { $_ eq $left } @{$right} ) ? 1 : 0 )' );
    }

    # If we get this far we do not know how to cope with whatever is in 'value'
    $self->_failure( "Handling of reference type '$ref_type' for 'value' not implemented" );
    return;
}


#
# the following are used to record errors
#

# populate 'error' and 'has_error'
sub _failure {
    my ( $self, $error_args )   = @_;

    $self->error( $error_args );
    $self->has_error( 1 );

    my $msg = $self->_dump_error;
    $self->xtlogger->error( $msg );

    if ( $self->die_on_error ) {
        croak "Failure in '" . __PACKAGE__ . "' can't continue, Error Dump: ${msg}";
    }

    return 0;
}

# dumps '$self->error'
sub _dump_error {
    my $self    = shift;

    my $error   = $self->error;

    my $dump    = '';
    eval {
        $dump   = pp( $error );
        $dump   .= "\nPassed in 'to_evaluate': " . pp( $self->to_evaluate );
    };
    if ( my $err = $@ ) {
        $dump   = "Couldn't Dump 'error' because: ${err}";
    }

    return $dump;
}

#-----------------------------------------------------------------------------

sub _build_channel {
    my $self    = shift;

    my $channel;

    OBJECT:
    foreach my $object ( $self->all_objects ) {
        # go through all Objects in the 'objects' list looking
        # for either a 'channel' or 'get_channel' method
        if ( $object->can('channel') ) {
            $channel    = $object->channel;
            last OBJECT;
        }
        if ( $object->can('get_channel') ) {
            $channel    = $object->get_channel;
            last OBJECT;
        }
    }

    if ( !$channel ) {
        croak "Couldn't derive Sales Channel from list of Objects, for '" . __PACKAGE__ . "::_build_channel'";
    }

    return $channel;
}

sub _build_schema {
    my $self    = shift;
    return $self->channel->result_source->schema;
}


sub _build__json {
    my $self    = shift;

    return JSON->new();
}

# interpret different boolean values
# and return the appropriate constant
sub _get_boolean_outcome {
    my ( $self, $value )    = @_;

    if ( $value =~ /^(true|t|y|1)$/i ) {
        return $BOOLEAN_TRUE;
    }

    if ( $value =~ /^(false|f|n|0)$/i ) {
        return $BOOLEAN_FALSE;
    }

    return;
}

# a helper to do debug logging with a
# consistant prefix to aid in debugging
sub _log_debug {
    my ( $self, $msg )  = @_;

    local $Log::Log4perl::caller_depth += 1;

    my $class   = $self->to_evaluate->{class} // '';
    my $method  = $self->to_evaluate->{method} // '';
    my $prefix  = "Condition using Class: '${class}' and Method: '${method}'";

    $self->xtlogger->debug( "${prefix} - ${msg}" );

    return;
}

