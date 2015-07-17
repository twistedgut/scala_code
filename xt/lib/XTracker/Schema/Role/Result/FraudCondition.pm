package XTracker::Schema::Role::Result::FraudCondition;
use NAP::policy "tt", 'role';
with 'XTracker::Role::WithXTLogger';

=head1 XTracker::Schema::Role::Result::FraudCondition

Currently a Role for:
    * Result::Fraud::StagingCondition
    * Result::Fraud::LiveCondition
    * Result::Fraud::ArchivedCondition

=cut

use XTracker::Utilities         qw( string_to_boolean );

use XT::Rules::Condition;

use Carp;


=head2 textualise

    $string = $self->textualise;

Turns into English the Condition by looking at the Condition's: Method,
Operator and Value.

=cut

sub textualise {
    my $self    = shift;

    my $method      = $self->method;
    my $operator    = lc( $self->conditional_operator->description );
    my $value       = $self->value;

    if ( $method->is_boolean ) {
        $value      = ( string_to_boolean( $value ) ? 'True' : 'False' );
        $operator   = '';
    }
    else {
        if ( $self->conditional_operator->is_list_operator ) {
            my $ruleset = $self->_get_ruleset();
            my $list = $self->result_source->schema->resultset('Fraud::'.$ruleset.'List')->find($self->value);

            $value = defined $list ? $list->name : 'null';
        }
        # if the Method has a Helper function
        # then get the Value from there
        elsif ( $method->rule_action_helper_method ) {
            # if it doesn't find any thing then use itself
            $value  = $method->get_an_allowable_value_from_helper( $value ) // $value;
        }
        $value  = " '" . ( defined $value ? $value : 'null' ) . "'";
    }

    # List operators have "is" already
    my $is = $self->conditional_operator->is_list_operator ? '' : 'is ';

    my $text = $method->description . " ${is}${operator}${value}";

    return $text;
}

=head2 compile

    $engine_condition_object  = $self->compile( [ objects, to, run, methods, against ], $optional_cache );

This will return an instance of 'XT::Rules::Condition' and have called the
'compile' method on it so it is ready to be 'evaluate'd.

Pass in a list of objects that the Method for the Condition can be used against.

Passing in a Cache will allow Method Calls and Place Holders to be Cached over multiple Conditions.

=cut

sub compile {
    my ( $self, $object_list, $cache )  = @_;

    if ( !$object_list || !scalar( @{ $object_list } ) ) {
        croak "Missing List of Objects, for '" . __PACKAGE__ . "::compile'";
    }

    my $method  = $self->method;
    my $operator= $self->conditional_operator;

    $self->xtlogger->debug( "Processing Condition Id: '" . $self->id . "', using Method: '" . $method->description . "'" );

    if ( $operator->is_list_operator ) {
        # For list operators the value will get passed as a place holder which
        # will require a XT::FraudRules::JsonData object.

        my $rs = 'XTracker::Schema::ResultSet::Fraud::' . $self->_get_ruleset . 'List';

        my $already_in_object_list = scalar( grep { ref $_ eq $rs } @$object_list );

        if ( ! $already_in_object_list ) {
            push @$object_list, $self->result_source->schema->resultset('Fraud::' . $self->_get_ruleset . 'List');
        }
    }

    my $condition = XT::Rules::Condition->new( {
        objects      => $object_list,
        cache        => $cache,
        die_on_error => 1,
        to_evaluate  => {
            class    => $method->object_to_use,
            method   => $method->method_to_call,
            params   => $method->method_parameters,
            operator => (
                $method->is_boolean && !$operator->perl_operator
                ? 'boolean'
                : $operator->perl_operator
            ),
            value   => $self->_get_value,
        },
        logger  => $self->xtlogger,
    } );

    # compile the Condition
    if ( !$condition->compile ) {
        croak "Couldn't Compile Condition '" . $self->id . "', for '" . __PACKAGE__ . "::compile'";
    }

    return $condition;
}

=head2 evaluate

    $engine_condition_object   = $self->evaluate( $object_list, $cache );

This will call 'compile' and then 'evaluate' it and return back an instance of
'XT::Rules::Condition' which you can then call one of the following methods
on to see if it worked:

    has_passed
    has_failed
    has_error

=cut

sub evaluate {
    my ( $self, $object_list, $cache )  = @_;

    if ( !$object_list || !scalar( @{ $object_list } ) ) {
        croak "Missing List of Objects, for '" . __PACKAGE__ . "::evaluate'";
    }

    return $self->compile( $object_list, $cache )
                    ->evaluate;
}

sub _get_ruleset {
    my $self = shift;
    return $self->rule->has_column('live_rule_id') ? 'Staging' : 'Live';
}

sub _get_value {
    my $self = shift;

    return $self->conditional_operator->is_list_operator ?
        $self->_make_list_placeholder :
        $self->value;
}

sub _make_list_placeholder {
    my $self = shift;

    my $list_id = $self->value;
    my $rs = 'XTracker::Schema::ResultSet::Fraud::' . $self->_get_ruleset . 'List';

    return "P[AMC.$rs.values_by_list_id($list_id)]";
}

1;
