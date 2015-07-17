package Test::XT::Data::FraudRule;

use NAP::policy "tt",     qw( test role );

# will also require a Sales Channel and Fraud Change Log
requires qw(
            schema
        );

=head1 NAME

Test::XT::Data::FraudRule

=head1 SYNOPSIS

Used for creating Fraud Rules and Conditions.

By Default this will create a Staging Rule with 5 Conditions on it.

If a Live Rule is created then this will actually create 3 versions of it:
Archived, Live & Staging it will also create a Change Log record, The Rule
you will get returned is the Live Rule.

=head2 USAGE

    use Test::XT::Flow;
            or
    use Test::XT::Data;

    my $framework = Test::XT::(Data|Flow)->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',          <--- required
            'Test::XT::Data::FraudChangeLog',   <--- only required for 'Live' Rules
            'Test::XT::Data::FraudRule',
        ],
    );

    # Returns a Fraud Rule
    my $rule    = $framework->fraud_rule;

    # Returns All Conditions created for the Fraud Rule
    # when used on its own will create the Rule first
    my $array_ref   = $framework->conditions;

=cut

use XTracker::Constants::FromDB     qw(
                                        :order_status
                                        :fraud_rule_status
                                    );
use Test::XTracker::Data;

use String::Random;


=head2 MOOSE ATTRIBUTES

The following can be overridden with your own choosing before the Fraud Rule is created.

    # the following will determin how many Conditions are Created, defaults to 5

    $framework->number_of_conditions( 3 );

        or

    # this would create a Rule with 4 conditions
    $framework->conditions_to_use( [
        {
            # use DBIC Objects to specify what Methods & Operators the Conditions should use
            method   => $method_obj,
            operator => $conditional_operator_obj,
            value    => 'value to compare',
        },
        {
            # or just specify the Description of the Methods & Conditions to use
            method   => 'Description of Method in fraud.method table',
            operator => '=',
            value    => 'value to compare',
        },
        {
            # or a combination
            method   => $method_obj,
            operator => '=',
            value    => 'value to compare',
        },
        {
            # if you don't specify a 'value' a random one will be assigned
            method   => 'Description of Method in fraud.method table',
            operator => '=',
        },
    ] );

Any Other Attribute can be set to your own data as well.

=head2 fraud_rule

This can't be overridden and is what is used to create the Rules.

=cut

has fraud_rule => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_set_fraud_rule',
);

=head2 rule_type

The Type of Rule can be either 'Live' or 'Staging', defaults to 'Staging'.

=cut

has rule_type => (
    is      => 'rw',
    isa     => 'Str',
    default => 'Staging',
);

=head2 rule_status_id

Set the Rule Status for Staging Rules will default to 'Unchanged'.

=cut

has rule_status_id => (
    is      => 'rw',
    isa     => 'Int',
    default => $FRAUD_RULE_STATUS__UNCHANGED,
);

=head2 rule_sequence

The Sequence the Rule will be processed in when put with all of the other Rules.

=cut

has rule_sequence => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    builder => '_set_rule_sequence',
);

=head2 rule_name

The Name you want to give the Rule, will need to be unique.

=cut

has rule_name => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    builder => '_set_rule_name',
);

=head2 rule_start_date

The Start Date of the Rule, default 'undef'.

=cut

has rule_start_date => (
    is      => 'rw',
    isa     => 'DateTime|Undef',
    default => undef,
);

=head2 rule_end_date

The End Date of the Rule, default 'undef'.

=cut

has rule_end_date => (
    is      => 'rw',
    isa     => 'DateTime|Undef',
    default => undef,
);

=head2 rule_action_status_id

The Order Status that the Rule will set, default 'Credit Hold'.

=cut

has rule_action_status_id => (
    is      => 'rw',
    isa     => 'Int',
    default => $ORDER_STATUS__CREDIT_HOLD,
);

=head2 rule_enabled

Whether the Rule is Enabled or Not

=cut

has rule_enabled => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

=head2 rule_tag_list

The list of tags for a rule.

=cut

has rule_tag_list => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub{ [ 'Tag 1', 'Tag 2' ] },
);

=head2 number_of_conditions

The Number of Conditions that will be created for the Rule, default 5.

The Conditions will be made up of Random Methods with Random Operators,
if you want to specify exactly the conditions then set the attribute
'conditions_to_use'.

=cut

has number_of_conditions => (
    is      => 'rw',
    isa     => 'Int',
    default => 5,
);

=head2 conditions_to_use

An ArrayRef that will be used to create all the Condtions for the Rule:

    [
        {
            # use DBIC Objects to specify what Methods & Operators the Conditions should use
            method   => $method_obj,
            operator => $conditional_operator_obj,
            value    => 'value to compare',
        },
        {
            # or just specify the Description of the Methods & Conditions to use
            method   => 'Description of Method in fraud.method table',
            operator => '=',
            value    => 'value to compare',
        },
        {
            # or a combination
            method   => $method_obj,
            operator => '=',
            value    => 'value to compare',
        },
        {
            # if you don't specify a 'value' a random one will be assigned
            method   => 'Description of Method in fraud.method table',
            operator => '=',
        },
    ]

=cut

has conditions_to_use => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    builder => '_set_conditions_to_use',
    traits  => ['Array'],
    handles => {
        get_all_conditions_to_use   => 'elements',
    },
);

=head2 auto_create_staging

Determines whether Staging rules and conditions will automatically be created for us
when we ask for Live rules and conditions.

Normally when we ask for Live rules and conditions, we'll get a Staging and Archive
copy as well for free, sometimes the Staging copy is not desired. To turn this off
set this attribute to false.

=cut

has 'auto_create_staging' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 1,
);

# Create a Fraud Rule
sub _set_fraud_rule {
    my $self    = shift;

    note "Creating a '" . $self->rule_type
         . "' Fraud Rule for Sales Channel: " . ( $self->channel ? $self->channel->name : 'All Channels' );

    # the Schema Class to use
    my $class_prefix = $self->_get_dbic_class_for_rule;

    my $rule_rs     = $self->schema->resultset("Fraud::${class_prefix}Rule");

    my %extra_fields;
    if ( $self->is_staging_rule ) {
        $extra_fields{rule_status_id}   = $self->rule_status_id;
    }
    if ( $self->is_live_rule ) {
        # these fields are actually for 'archived_rule' as
        # that has to be created first
        $extra_fields{change_log_id}          = $self->fraud_change_log->id;
        $extra_fields{created_by_operator_id} = $self->operator->id;
    }

    my $rule    = $rule_rs->create( {
        channel_id              => ( $self->channel ? $self->channel->id : undef ),
        rule_sequence           => $self->rule_sequence,
        name                    => $self->rule_name,
        start_date              => $self->rule_start_date,
        end_date                => $self->rule_end_date,
        action_order_status_id  => $self->rule_action_status_id,
        enabled                 => $self->rule_enabled,
        tag_list                => $self->rule_tag_list,
        %extra_fields,
    } );

    my $create_msg;
    if ( $self->is_live_rule ) {
        $create_msg = "Fraud Rule Created 'fraud.archived_rule' table: (" . $rule->id . ")";
    }
    else {
        $create_msg = "Fraud Rule Created: (" . $rule->id . ")";
    }
    my $order_status = $rule->action_order_status->status;
    note "${create_msg} '" . $rule->name . "', Sequence: " . $self->rule_sequence
         . ", Outcome if Passes: '" . $rule->action_order_status->status . "'";

    foreach my $condition ( $self->get_all_conditions_to_use ) {
        my $method_obj      = $self->_get_method( $condition->{method} );
        my $operator_obj    = $self->_get_conditional_operator( $condition->{operator}, $method_obj );

        # update the processing cost of the Method if asked to
        if ( my $cost = $condition->{processing_cost} ) {
            $method_obj->update( { processing_cost => $cost } );
        }

        my $condition   = $rule->create_related( lc( $class_prefix ) . '_conditions', {
            method_id               => $method_obj->id,
            conditional_operator_id => $operator_obj->id,
            value                   => $condition->{value} // $self->_get_value_for_method( $method_obj ),
            enabled                 => $condition->{enabled} // 1,
            ( $self->is_live_rule ? %extra_fields : () ),
        } );

        note "    Condition Created: (" . $condition->id . ") " .
             $method_obj->description . " " . $operator_obj->symbol . " '" . $condition->value . "'";
    }

    if ( $self->is_live_rule ) {
        # now create the Live & Staging (only if required) rule from the Archived Rule
        my $live_rule = $self->schema->resultset('Fraud::LiveRule')->create( {
            channel_id              => $rule->channel_id,
            rule_sequence           => $rule->rule_sequence,
            name                    => $rule->name,
            start_date              => $rule->start_date,
            end_date                => $rule->end_date,
            action_order_status_id  => $rule->action_order_status_id,
            enabled                 => $rule->enabled,
            archived_rule_id        => $rule->id,
            tag_list                => $rule->tag_list,
        } );

        my $staging_rule;

        if ( $self->auto_create_staging ) {
        # Only create a Staging rule if required.

            $staging_rule = $self->schema->resultset('Fraud::StagingRule')->create( {
                channel_id              => $rule->channel_id,
                rule_sequence           => $rule->rule_sequence,
                name                    => $rule->name,
                start_date              => $rule->start_date,
                end_date                => $rule->end_date,
                action_order_status_id  => $rule->action_order_status_id,
                enabled                 => $rule->enabled,
                rule_status_id          => $FRAUD_RULE_STATUS__UNCHANGED,
                live_rule_id            => $live_rule->id,
                tag_list                => $rule->tag_list,
            } );

        }

        my @conditions  = $rule->archived_conditions->search( {}, { order_by => 'id' } )->all;
        foreach my $condition ( @conditions ) {
            $live_rule->create_related( 'live_conditions', {
                rule_id                 => $live_rule->id,
                method_id               => $condition->method_id,
                conditional_operator_id => $condition->conditional_operator_id,
                value                   => $condition->value,
                enabled                 => $condition->enabled,
            } );

            if ( $self->auto_create_staging ) {
            # Only create Staging conditions if required.

                $staging_rule->create_related( 'staging_conditions', {
                    rule_id                 => $staging_rule->id,
                    method_id               => $condition->method_id,
                    conditional_operator_id => $condition->conditional_operator_id,
                    value                   => $condition->value,
                    enabled                 => $condition->enabled,
                } );

            }
        }

        note "    Fraud Rule Created 'fraud.live_rule' table: (" . $live_rule->id . ") " . $live_rule->name;

        if ( $self->auto_create_staging ) {
            note "    Fraud Rule Created 'fraud.staging_rule' table: (" . $staging_rule->id . ") " . $staging_rule->name
        } else {
            note "    Fraud Rule SKIPPED 'fraud.staging_rule' table";
        }

        $rule   = $live_rule;
    }

    return $rule->discard_changes;
}

sub _set_rule_sequence {
    my $self    = shift;

    # work out the highest sequence over the two tables
    my $live_seq    = $self->schema->resultset('Fraud::LiveRule')->get_column('rule_sequence')->max // 0;
    my $staging_seq = $self->schema->resultset('Fraud::StagingRule')->get_column('rule_sequence')->max // 0;
    my $sequence    = ( $live_seq > $staging_seq ? $live_seq : $staging_seq );
    $sequence++;

    return $sequence;
}

sub _set_rule_name {
    my $self    = shift;
    return "Test Name of a Rule that makes sure Orders aren't a Fraud "
           . $self->rule_sequence;
};

# sets the Methods & Operators to use for the Conditions
sub _set_conditions_to_use {
    my $self    = shift;

    my @all_methods = $self->schema->resultset('Fraud::Method')
                                    ->search
                                        ->all;
    my @methods;

    # get the number of methods required
    # but from random poistions so that the
    # same Methods aren't used all the time
    foreach ( 1..$self->number_of_conditions ) {
        my $rand_idx    = int( rand( scalar @all_methods ) );
        push @methods, $all_methods[ $rand_idx ];
        splice @all_methods, $rand_idx, 1;
    }

    my @conditions_to_use;
    foreach my $method ( @methods ) {
        my @operators   = $method->return_value_type
                                    ->link_return_value_type__conditional_operators
                                        ->all;
        # get a random operator so not always the same one used everytime
        my $operator    = $operators[ int( rand( scalar @operators ) ) ]->conditional_operator;

        my $value   = $self->_get_value_for_method( $method );

        push @conditions_to_use, {
            method  => $method,
            operator=> $operator,
            value   => $value,
        };
    }

    return \@conditions_to_use;
}

# convert the Rule Stage to
# the DBIC Class to use
sub _get_dbic_class_for_rule {
    my $self    = shift;

    my $class_name;
    given ( lc( $self->rule_type ) ) {
        when ('staging') {
            $class_name = 'Staging';
        }
        when ('live') {
            # you have to create an Archived Rule
            # first before you can copy it to live
            $class_name = 'Archived';
        }
    }

    return $class_name;
}

sub is_staging_rule     { return ( lc( shift->rule_type ) eq 'staging'  ? 1 : 0 ) }
sub is_live_rule        { return ( lc( shift->rule_type ) eq 'live'     ? 1 : 0 ) }

# helper to return a value for a Method's data type
sub _get_value_for_method {
    my ( $self, $method ) = @_;

    my %possible_values = (
        boolean     => ( 'true', 'false' )[ int(rand(2)) ],
        string      => String::Random->new( max => 15 )->randregex('[A-Za-z]{3,}'),
        integer     => int( rand(100) ),
        decimal     => sprintf( '%0.2f', ( rand(10000) / 1.5 ) ),
        dbid        => int( rand(100) ),
    );

    my $value_to_use;
    my $values  = $method->get_allowable_values_from_helper;
    if ( my $num_elements = scalar( @{ $values } ) ) {
        $value_to_use   = $values->[ int( rand( $num_elements ) ) ]->get_column('id');
    }
    else {
        my $value_type  = $method->return_value_type;
        $value_to_use   = $possible_values{ $value_type->type };
    }

    return $value_to_use;
}

# helper to get the Method object
# from a Method Description
sub _get_method {
    my ( $self, $method )   = @_;

    if ( ref( $method ) ) {
        # if it is a Method then just Return
        return $method;
    }

    return $self->schema->resultset('Fraud::Method')
                            ->search( { 'LOWER(description)' => lc( $method ) } )
                                ->first
    ;
}

# helper to get the Operator
# Id from the symbol itself
sub _get_conditional_operator {
    my ( $self, $operator, $method )    = @_;

    if ( ref( $operator ) ) {
        # if it is the ConditionalOperator then just Return
        return $operator;
    }

    return $self->schema->resultset('Fraud::ConditionalOperator')
                            ->search(
        {
            symbol  => $operator,
            'link_return_value_type__conditional_operators.return_value_type_id' => $method->return_value_type_id,
        },
        {
            join => 'link_return_value_type__conditional_operators',
        }
    )->first;
}

1;
