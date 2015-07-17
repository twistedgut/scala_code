package Test::XT::FraudRules::JsonData;
use NAP::policy "tt", 'test';

use parent "NAP::Test::Class";

use JSON;

=head1 NAME

Test::XT::FraudRules::JsonData

=head1 TESTS

=head2 startup

 * Checks all the required modules can be used OK.
 * Creates class object.

=cut

sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    use_ok 'Test::XTracker::Data';
    use_ok 'Test::XTracker::Data::FraudRule';
    use_ok 'XT::FraudRules::JsonData';
    use_ok 'JSON';

    $self->{schema} = Test::XTracker::Data->get_schema;

}

sub setup : Test(setup => 0 ) {
    my $self = shift;

    $self->SUPER::setup;

    $self->schema->txn_begin;

}
sub teardown : Test( teardown => 0 ) {
    my $self = shift;

    $self->SUPER::teardown;
    $self->schema->txn_rollback;
}


sub test_missing_attribute : Tests() {
    my $self  = shift;

    # Dies  when required parameter 'schema' is  missing
    throws_ok(
        sub { XT::FraudRules::JsonData->new },
            qr/Attribute \(schema\) is required/,
                'dies with missing schema attribute'
        );

}


sub test_populate_operators :Tests() {
    my $self = shift;

    # build a test hash
    foreach my $type ( 'boolean' ,'dbid', 'integer' ) {

        my $return_type = $self->schema->resultset('Fraud::ReturnValueType')
            ->search( { type => $type})
                ->first;

        # Build up Expected Result
        my $expected_data = {};
        my @return_arr;
        foreach my $operator ( $return_type->link_return_value_type__conditional_operators ) {
            push (@return_arr , {
                id => $operator->conditional_operator->id,
                value => $operator->conditional_operator->description,
                list => $operator->conditional_operator->is_list_operator,
            });
        }
        $expected_data->{$return_type->type} = \@return_arr;

        my $data_obj = XT::FraudRules::JsonData->new({
            schema => $self->schema
        });

        my $got_data = $data_obj->_populate_operators();

        #check the key exist
        is( ref($got_data), 'HASH', "Operators type $type - Returns result of expected type");
        is( ref($got_data->{$return_type->type}), 'ARRAY', "Operators - Each item is of expected type $type");
        ok( exists $got_data->{$return_type->type}, $return_type->type ."Operator type $type - key exists" );
        is_deeply( $got_data->{$return_type->type},
            $expected_data->{$return_type->type} ,
            "Operator Data for $type populates correctly"
        );
    }

}


sub test_populate_rule_status : Tests() {
    my $self = shift;

    my $rulestatus = $self->schema->resultset('Fraud::RuleStatus');

    my $expected_data = {};
    foreach my $status (  $rulestatus->all ) {
        $expected_data->{$status->status} = $status->id;
    }

    my $data_obj = XT::FraudRules::JsonData->new({
        schema => $self->schema
    });

    is_deeply( $data_obj->_populate_rulestatus(),
        $expected_data ,
        "Rule Status data is populated correctly "
    );
}

sub test_populate_methods : Tests() {
    my $self  = shift;

    my $method = $self->schema->resultset('Fraud::Method')->first;

    my @values = ();
    foreach my $value ( @{$method->get_allowable_values_from_helper} ) {
        push(@values, {
            id => $value->get_column('id'),
            description => $value->get_column('value')
        });
    }

    my @lists;
    if ( $method->list_type_id ) {
        foreach my $list ( $method->list_type->staging_lists->all ) {
            push @lists, {
                id          => $list->id,
                name        => $list->name,
            };
        }
    }

    my $expected_data->{'method_'.$method->id} = {
        id => $method->id,
        name    => $method->description,
        valueType => $method->return_value_type->type,
        returnValues => \@values,
        listValues => \@lists,
    };



    my $data_obj = XT::FraudRules::JsonData->new({
        schema => $self->schema
    });


    is(ref ($data_obj->_populate_methods->{methods} ),
        'HASH',
        'Methods data is of expected Type'
    );

    is_deeply( $expected_data->{'method_'.$method->id},
        $data_obj->_populate_methods->{methods}->{'method_'.$method->id},
        " Methods Data is populated as expected "
    );
}


sub test_populate_fraud_rules : Tests() {
    my $self = shift;

    foreach my $rule_type ( 'Staging', 'Live' ) {
        #create a rule
        my $rule = Test::XTracker::Data::FraudRule->create_fraud_rule( $rule_type, {
            how_many          => 1,
            conditions_to_use => [ {
                method   => 'Order Total Value',
                operator => '<',
                value    => 50,
            } ]
        });

        my $rule_number = $self->schema->resultset('Fraud::'.$rule_type.'Rule')->count();

        my $condition = ($rule->get_all_conditions)[0];
        my $expected_data = {};

        $expected_data = {
              'sequence' => $rule->rule_sequence,
              'status' => ($rule_type eq 'Staging' ) ? $rule->rule_status_id : '',
              'rule_number' =>  $rule_number,
              'name' => $rule->name,
              'channel' => {
                             'id' => $rule->channel_id,
                             'description' => $rule->channel->business->config_section
                           },
              'deleted' => JSON->false,
              'end' => {
                         'hour' => '',
                         'minute' => '',
                         'date' => ''
                       },
              'action' => {
                            'id' => $rule->action_order_status->id,
                            'description' => $rule->action_order_status->status
                          },
              'id' => $rule->id,
              'conditions' => [
                                {
                                  'operator' => {
                                                  'id' => $condition->conditional_operator->id,
                                                  'description' => $condition->conditional_operator->description,
                                                  list_operator => $condition->conditional_operator->is_list_operator,
                                                },
                                  'value' => {
                                               'id' => '50',
                                               'description' => '50'
                                             },
                                  'deleted' => JSON->false,
                                  'method' => {
                                                'id' => $condition->method->id,
                                                'description' => $condition->method->description,
                                              },
                                  'id' => $condition->id,
                                  'enabled' => JSON->true,
                                }
                              ],
              'enabled' => JSON->true,
              'start' => {
                           'hour' => '',
                           'minute' => '',
                           'date' => ''
                         },
              'tags' => $rule->tag_list,
            };

        my $data_obj = XT::FraudRules::JsonData->new({
            schema => $self->schema,
            rule_set => lc($rule_type),
        });

        my $got_data = $data_obj->_populate_rules();

        my @got =  grep { $_->{id}  == $rule->id } @{ $got_data};
        is_deeply( $got[0] ,$expected_data, "Rules Data for $rule_type was populate as expected" );
    }

}

sub test_get_list_as_json_array : Tests {
    my $self = shift;

    my $list_types = $self->schema->resultset('Fraud::ListType')->search({});

    my @test_list = (qw/ This is a simple list of things /);

    # Create a list
    my $list = $self->schema->resultset('Fraud::StagingList')->create({
        list_type_id        => $list_types->first->id,
        name                => 'unit_test_list',
        description         => 'List Created for use in Unit Test',
    } );

    # Add some entries to the test list
    foreach my $list_value ( @test_list ) {
        $list->create_related('list_items', {
            value   => $list_value,
        } );
    }

    # Instantiate XT::FraudRules::JsonData and call get_list_as_json_array
    my $json_data = XT::FraudRules::JsonData->new( {
        schema      => $self->schema,
        rule_set    => 'staging',
    } );

    isa_ok( $json_data, 'XT::FraudRules::JsonData');

    my $json_list = $json_data->get_list_as_json_array($list->id);
    ok( $json_list, "get_list_as_json_array returns a value" );

    my $returned_list = JSON->new->decode($json_list);
    ok( $returned_list, "The returned value can be JSON decoded" );
    ok( ref $returned_list eq 'ARRAY', "The returned value is a list" );

    # Verify that the JSON returned is the same list
    cmp_deeply( $returned_list, bag(@test_list) );
}
