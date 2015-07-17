package XT::FraudRules::JsonData;
use NAP::policy "tt", 'class';


use XT::FraudRules::Type;
use JSON::XS;

use XTracker::Database::Utilities   qw( is_valid_database_id );

=head1 NAME

XT::FraudRules::JsonData

=head1 DESCRIPTION

Provides common method to populate JSON data to be used for CONRAD.

=head1 SYSNOPSIS

    my $class_obj = XT::FraudRules::JsonData->new({
        schema      => $schema,
        rule_set     => 'live'|'staging',
    });

    my $json_data = $class_obj->build_data;

    print "Methods      => ".json_data->{methods} ."\n";
    print "Rules        => ".json_data->{rules} ."\n";
    print "Operators    => ".json_data->{operators} ."\n";
    print "Rule Status  => ".json_data->{rule_status} ."\n";

    my $json_array = $class_obj->get_list_as_json_array($list_id);


=head1 ATTRIBUTES

=head2 schema

DBIx::Class Schema Object

This attribute is required.

=cut

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    required => 1,
);

=head2 rule_set

'live' or 'staging' to indicate which rule set to use.

=cut

has 'rule_set' => (
    is       => 'ro',
    isa      => 'XT::FraudRules::Type::RuleSet',
    required => 0,
    default  => 'staging',
);

=head1 METHODS

=head2 build_data

Return a HASH Ref containing json data for methods, rules, rule status and
operators.

=cut

sub build_data {
    my $self = shift;

    # Build methods
    my $methods_hash = $self->_populate_methods;
    my $lookup_hash  = $methods_hash->{lookup};


    return  {
        rules        => JSON::XS->new->pretty->encode( $self->_populate_rules($lookup_hash) ),
        methods      => JSON::XS->new->pretty->encode( $methods_hash->{methods} ),
        operators    => JSON::XS->new->pretty->encode( $self->_populate_operators ),
        rule_status  => JSON::XS->new->pretty->encode( $self->_populate_rulestatus ),
        list_items   => JSON::XS->new->pretty->encode( $self->_populate_list_items ),
    };

}

=head2 get_list_as_array_ref

Returns the values of a list related to the rule_set as an array ref

=cut

sub get_list_as_array_ref {
    my ( $self, $id ) = @_;

    die "You must pass the list id" unless $id && is_valid_database_id($id);

    my $list_class = 'Fraud::'.ucfirst($self->rule_set).'List';

    my $list = $self->schema->resultset($list_class)->find($id);

    die "Unable to find list in '$list_class' with id '$id'" unless $list;

    return [ map { $_->value }
        $list->list_items->search( {}, { order_by => {-asc => 'id' } } )->all ];
}


=head2 get_list_as_json_array

Gets the values from a list related to the rule_set and returns the list as
a json array.

=cut

sub get_list_as_json_array {
    my ( $self, $id ) = @_;

    return JSON::XS->new->encode( $self->get_list_as_array_ref( $id ) );
}

=head2 _populate_methods

Build hash contianing json data of Fraud rule methods.

=cut

sub _populate_methods {
    my $self = shift;

    my @methods             = $self->schema->resultset('Fraud::Method')->get_methods_in_alphabet_order;
    my $existing_methods    = {};
    my $lookup_hash         = {};

    foreach my $method ( @methods ) {
        my $method_set = {
            id         => $method->id,
            name       => $method->description,
            valueType  => $method->return_value_type->type,
        };

        my @return_values;
        if( $method->has_allowable_values ) {
            foreach my $value ( @{$method->get_allowable_values_from_helper} ) {
                $lookup_hash->{$method->id}->{$value->get_column('id')} = $value->get_column('value');
                push(@return_values, {
                    id          => $value->get_column('id'),
                    description => $value->get_column('value'),
                });
            }
        }

        my @lists;
        if ( $method->list_type_id ) {
            $method_set->{listType} = $method->list_type->type;
            foreach my $list ( $method->list_type->staging_lists->all ) {
                push @lists, {
                    id          => $list->id,
                    name        => $list->name,
                };
            }
        }

        $method_set->{listValues} = \@lists;
        $method_set->{returnValues} = \@return_values;
        $existing_methods->{'method_'.$method->id} = $method_set;
    }

    return {
        methods => $existing_methods,
        lookup  => $lookup_hash,
    };

}

=head2 _populate_rules

Builds hash containing data for Fraud rules

=cut

sub _populate_rules {
    my $self        = shift;
    my $lookup_hash = shift;

    my @rules;
    if( $self->rule_set eq 'staging' ) {
        @rules = $self->schema->resultset('Fraud::StagingRule')->by_sequence;
    } else {
        @rules = $self->schema->resultset('Fraud::LiveRule')->by_sequence;
    }

    my @rules_set = ();
    my $rule_number = 1;
    foreach my $rule ( @rules ) {

        my $existing_rules = {
            id       => $rule->id,
            rule_number => $rule_number++,
            name     => $rule->name,
            sequence => $rule->rule_sequence,
            deleted  => JSON::XS::false,
            status   => ( $rule->can('rule_status') ) ? $rule->rule_status->id : '',
            enabled  => ( $rule->enabled ? JSON::XS::true : JSON::XS::false ),
            channel  => {
                id          => ($rule->channel_id ) ? $rule->channel_id : "",
                description => ($rule->channel_id ) ? $rule->channel->business->config_section : 'All'
            },
            start    => {
                date    => ($rule->start_date ) ? $rule->start_date->ymd() : "",
                hour    => ($rule->start_date ) ? sprintf('%02d',$rule->start_date->hour()) : "",
                minute  => ($rule->start_date ) ? sprintf('%02d',$rule->start_date->minute()) : ""
            },
            end      => {
                date    => ($rule->end_date ) ? $rule->end_date->ymd() : "",
                hour    => ($rule->end_date ) ? sprintf('%02d', $rule->end_date->hour()) : "",
                minute  => ($rule->end_date ) ? sprintf('%02d', $rule->end_date->minute()) : ""
            },
            action   =>  {
                id          => $rule->action_order_status->id,
                description => $rule->action_order_status->status,
            },
            tags => $rule->tag_list ? $rule->tag_list : [],
        };

        my @condition_set;
        foreach my $condition ( $rule->get_all_conditions() ) {
            my $value_hash = {};
            if ( $condition->conditional_operator->is_list_operator ) {
                my $list = $self->schema->resultset('Fraud::'.ucfirst($self->rule_set).'List')->find($condition->value);
                $value_hash = {
                    id          => $condition->value,
                    description => $list->name,
                };
            }
            else {
                SMARTMATCH: {
                    use experimental 'smartmatch';
                    given ( $condition->method->return_value_type->type ) {
                        when ( 'boolean' ) {
                            $value_hash = {
                                id           => $condition->value,
                                # these are labels not boolean values
                                description  => ( $condition->value ? 'True' : 'False' ),
                           };
                        }
                        when ( 'dbid' ) {
                            $value_hash = {
                                id          => $condition->value,
                                description => $lookup_hash->{$condition->method->id}->{$condition->value},
                            };
                        }
                        default {
                            $value_hash = {
                                id          => $condition->value,
                                description => $condition->value,
                            };
                        }
                    }
                }
            }

            my $condition_hash = {
                id        => $condition->id,
                method    => {
                    id          => $condition->method->id,
                    description => $condition->method->description,
                },
                operator  => {
                    id              => $condition->conditional_operator->id,
                    description     => $condition->conditional_operator->description,
                    list_operator   => $condition->conditional_operator->is_list_operator,
                },
                enabled  => ($condition->enabled) ? JSON::XS::true : JSON::XS::false,
                deleted  => JSON::XS::false,
                value    => $value_hash,
            };

            push(@condition_set, $condition_hash );
        }
        $existing_rules->{conditions} = \@condition_set;
        push( @rules_set, $existing_rules );
    }

    return (\@rules_set);

}

=head2 _populate_operators

Returns Array ref containing operators data of format

my $returned_hash = {
    'boolean' => [
        {
            value => 'Is',
            id    => 2,
        }
    ],
    integer => [
        {
          id => ...
            value => ...
        }
    ]
.....
};


=cut

sub _populate_operators {
    my $self = shift;

    my $operator_set = {};

    foreach my $return_type ( $self->schema->resultset('Fraud::ReturnValueType')->all ) {
        my @return_type;
        foreach my $operator_return_type ( $return_type->link_return_value_type__conditional_operators ) {
            push( @return_type, {
                id    => $operator_return_type->conditional_operator->id,
                value => $operator_return_type->conditional_operator->description,
                list  => $operator_return_type->conditional_operator->is_list_operator,
            } );

        }
        $operator_set->{$return_type->type} = \@return_type;
    }

    return $operator_set;
}

=head2 _populate_rulestatus

Return hash ref containing rule status.

=cut

sub _populate_rulestatus {
    my $self = shift;

    my $rule_status = {};

    foreach my $status (  $self->schema->resultset('Fraud::RuleStatus')->all ) {
        $rule_status->{$status->status} = $status->id;
    }

    return $rule_status;
}

=head2 _populate_list_items

Return a HashRef of all the list items for every list, with the list
id as a key.

=cut

sub _populate_list_items {
    my $self = shift;

    return {
        map { $_->id => $_->resolved_list_items }
            $self
                ->schema
                ->resultset(
                    'Fraud::' .
                    ucfirst( $self->rule_set ) .
                    'List'
                )
                ->all
    };

}

1;
