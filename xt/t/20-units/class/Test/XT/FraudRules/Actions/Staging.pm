package Test::XT::FraudRules::Actions::Staging;
use NAP::policy 'test';
use parent "NAP::Test::Class";

use XTracker::Constants::FromDB qw(
    :order_status
    :fraud_rule_status
);

use XTracker::Constants qw(
    $APPLICATION_OPERATOR_ID
);

use Test::XTracker::Mock::Handler;
use JSON qw(to_json);

use Test::MockModule;

use Data::Dumper;

=head1 NAME

Test::XT::FraudRules::Actions::Staging

=head1 TESTS

=head2 startup

 * Checks all the required modules can be used OK.
 * Creates class object.

=cut

sub startup : Test( startup => 4 ) {
    my $self = shift;
    $self->SUPER::setup;

    use_ok 'Test::XTracker::Data';
    use_ok 'Test::XTracker::Data::FraudRule';
    use_ok 'XT::FraudRules::Actions::Staging';
    use_ok 'XTracker::Constants::FromDB', qw(
        :fraud_rule_status
    );

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{mock_send_mail}  = Test::MockModule->new('XTracker::EmailFunctions');
    $self->{schema}->txn_begin;

}

=head2 test_valid_payload

    Tests valid payload return ok => 1

=cut

sub test_valid_payload : Tests {
    my $self = shift;

    my $class_obj = $self->_get_class( $self->_construct_payload );
    my $result    = $class_obj->validate($self);

    is( $result->{ok} ,1 , "Valid payload");

}

=head2 test_repeated_payload

 * check payload containing duplicate rule name and sequence throws
    error.
 * check payload having one rule marked as deleted and other having same rule name
    does not throw up error.

=cut

sub test_repeated_payload :Tests {
    my $self = shift;

    my $payload = [];
    push (@$payload, $self->_construct_payload()->[0]);
    push (@$payload, $self->_construct_payload()->[0]);

    my $class_obj   = $self->_get_class( $payload);
    my $result      = $class_obj->validate(1);

    is($result->{ok} , 0 , 'Payload Has error');

    # Test for error : rule name/sequence is not unique error message.
    my $err_msgs = $result->{ruleset}->[0]->{error_msg};
    if( grep { $_ && $_ eq 'Rule name is duplicate. It has to be unique' } @$err_msgs ) {
        pass('Got expected error message : Rule Name is Repeated');
    } else {
        fail('Payload did not return expected error - Rule name is repeated');
    }

    if( grep { $_ && $_ eq 'Sequence is duplicate. It has to be unique' } @$err_msgs ) {
        pass('Got expected error message : Sequence is Repeated');
    } else {
        fail('Payload did not return expected error - Sequence is repeated');
    }

    # Test : validation passes if one rule is marked as deleted
    # even though it is repeated in payload
    $payload = [];
    push (@$payload,$self->_construct_payload()->[0]);
    push (@$payload,$self->_construct_payload()->[0]);
    $payload->[0]->{deleted} = JSON::true;

    $class_obj = $self->_get_class($payload);
    $result = $class_obj->validate(1);
    is($result->{ok} , 1, 'Payload is Valid' );

}

=head2 test_empty_rulename

    check empty rule name in payload is not allowed

=cut

sub test_empty_rulename : Tests {
    my $self = shift;

    my $payload = $self->_construct_payload;
    #test for rule name empty
    $payload->[0]->{name} = '';
    my $class_obj = $self->_get_class($payload);
    my $result = $class_obj->validate(1);

    is($result->{ok} , 0, 'Payload has error');
    my $err_msgs = $result->{ruleset}->[0]->{error_msg};
    if( grep { $_ && $_ eq 'Rule name cannot be null' } @$err_msgs ) {
        pass('Got expected error message : Rule name cannot be null');
    } else {
        fail('Payload did not return expected error - Rule name cannot be null');
    }

}

=head2 test_payload_with_no_conditions

    Check enabled rule with no conditions throws up error

=cut

sub test_payload_with_no_conditions : Tests {
    my $self = shift;

    my $payload = $self->_construct_payload;
    $payload->[0]->{conditions} =[];

    my $class_obj = $self->_get_class($payload);
    my $result = $class_obj->validate(1);

    is($result->{ok} , 0 , 'Payload Has error');
    my $err_msgs = $result->{ruleset}->[0]->{error_msg};

    if( grep { $_ && $_ eq 'Please disable the rule, as it does not have any enabled condition(s)' } @$err_msgs ) {
        pass('Got expected error message : Rule with no conditions should be disabled');
    } else {
        fail('Payload did not return expected error - Rule with no conditions should be disabled');
    }

}

=head2 test_for_valid_operator

    Check valid operator is used.

=cut

sub test_for_valid_operator : Tests {
    my $self = shift;

    # created payload with boolean operator
    my $payload = $self->_construct_payload;

    #get operator for operator for string
    my $return_type_value = $self->_get_return_value_type('string');
    my $operator = $return_type_value->link_return_value_type__conditional_operators->first;

    #fudge the conditional operator
    $payload->[0]->{conditions}->[0]->{operator}->{id} = $operator->conditional_operator_id;

    my $class_obj = $self->_get_class($payload);
    my $result = $class_obj->validate(1);

    is($result->{ok} , 0 , 'Payload Has error');
    my $err_msgs = $result->{ruleset}->[0]->{conditions}->[0]->{error_msg};

    if( grep { $_ && $_ eq 'Incorrect operator used' } @$err_msgs ) {
        pass('Got expected error message : Incorrect Operator used');
    } else {
        fail('Payload did not return expected error - Incorrect Operator used');
    }

}

=head2 test_for_valid_return_type

    Check value is correct return type

=cut

sub test_for_valid_return_type : Tests {
    my $self = shift;

    # created payload with boolean operator
    my $payload = $self->_construct_payload;

    #fudge the value to be string
     $payload->[0]->{conditions}->[0]->{value}->{id} = 'This is string';

    my $class_obj = $self->_get_class($payload);
    my $result = $class_obj->validate(1);

    is($result->{ok} , 0 , 'Payload Has error');
    my $err_msgs = $result->{ruleset}->[0]->{conditions}->[0]->{error_msg};

    if( grep { $_ && $_ eq 'Value is of wrong type' } @$err_msgs ) {
        pass('Got expected error message : Value is of wrong type');
    } else {
        fail('Payload did not return expected error - Value is of wrong type');
    }
}

=head2 test_for_valid_listed_value

    Check value is from allowed list.

=cut

sub test_for_valid_listed_value : Tests {
    my $self = shift;

    my $method =  $self->schema->resultset('Fraud::Method')
        ->search({ description => 'Shipping Address Country' } )
        ->first;

   #create payload with dbic  operator
   my $payload = $self->_construct_payload(undef,$method->id);

   my $class_obj = $self->_get_class($payload);
   my $result = $class_obj->validate(1);

   is($result->{ok} , 0 , 'Payload Has error');
    my $err_msgs = $result->{ruleset}->[0]->{conditions}->[0]->{error_msg};

    if( grep { $_ && $_ eq 'Value provided is not from allowed list of values' } @$err_msgs ) {
        pass('Got expected error message : Value provided is not from allowed list of values');
    } else {
        fail('Payload did not return expected error - Value provided is not from allowed list of values');
    }

}

=head2 test_is_valid_return_type

For a given value make sure that regular expression in fraud.return_value_type table
passes correctly

=cut

sub test_is_valid_return_type : Tests {
    my $self = shift;

    my $data = {
        boolean => {
            valid => [ 't','f','true','false','1','0','y','n' ],
            invalid => [ 'abc','99']
        },
        decimal => {
            valid   => [ '11.2','-33','40.99', '+67','.00'],
            invalid => [ 'abc','12.A'],
        },
        integer => {
            valid => [ '+11' ,'-12','454'],
            invalid => [ '+11.0', '-13.00','.00'],
        },
        string => {
            valid => [ 'sds', 'www-111', 'wewew_eweq','11.00'],
            invalid => [ 'wqeqw;','rm.*'],
        },
        dbid => {
            valid => ['1','4','67'],
            invalid => ['3.0','-3','+7','country'],
        }
    };

    my $method_obj = $self->schema->resultset('Fraud::Method');

    # Get all return_types from database
    my $return_types = $self->{schema}->resultset('Fraud::ReturnValueType');
    while ( my $type = $return_types->next ) {
       # get a method with that retur_type
        my $method_rs = $self->_get_method($type->id);
        if (exists $data->{lc($type->type)} ) {
            my $test_data = $data->{lc($type->type)};

            # Test for valid values
            foreach my $dt ( @ {$test_data->{valid}} ) {
                my $result = XT::FraudRules::Actions::Staging::is_valid_return_type($method_rs,$dt);
                is ($result, 1, "Value is Correct for input type :".$type->type . "  and value = ". $dt);
            }

            # Test for invalid values
            foreach my $dt ( @ {$test_data->{invalid}} ) {
                my $result = XT::FraudRules::Actions::Staging::is_valid_return_type($method_rs,$dt);
                is ($result, 0, "Test Fails correctly for input type :".$type->type . "  and value = ". $dt);
            }

        } else {
            fail( "Test Data is not updated for type : ". $type->type. " which was added to table fraud.return_value_type");
        }
    }
}

sub test_prepare_data_for_output : Tests {
    my $self = shift;

    my $data = {
        Test1 => {
            input => {
                error => 'abcd',
                conditions => [],
            },
            output => {
                error => 'abcd',
                conditions => [],
            }
        },
        Test2 => {
            input => {
                ruleset => [
                    {
                        this => 'is',
                        conditions => [],
                    }
                ],
            },
            output => {
                ruleset => [
                    {
                        this => 'is',
                        conditions => [],
                    }
                ],
            }
        },
        Test3 => {
            input => {
                ruleset => [
                {
                    ok => 0,
                    error_msg => [  "Error1", "error2"],
                    'channel_id' => undef,
                    'sequence' => 5,
                    'name' => 'ssasa',
                    'action_id' => '1',
                    'deleted' => JSON::true,
                    'rule_id' => '287',
                    '_source' => {
                        'sequence' => 5,
                        'name' => 'ssasa',
                        'channel' => {
                            'id' => '',
                            'description' => ''
                        },
                        'deleted' => JSON::true,
                        'end' => {
                            'hour' => '',
                            'minute' => '',
                            'date' => ''
                        },
                        'action' => {
                            'id' => '1',
                            'description' => 'Credit Hold'
                        },
                        'idx' => 5,
                        'id' => '287',
                        'enabled' => JSON::false,
                        'start' => {
                            'hour' => '',
                             'minute' => '',
                             'date' => ''
                        }
                    },
                    'end_date' => '',
                    'start_date' => '',
                    'conditions' => [
                        {
                            error_msg => [ 'Conditions has error'],
                            '_source' => {
                                'operator' => {
                                    'id' => '1',
                                    'description' => 'Equal To'
                                },
                                'value' => {
                                    'id' => '2',
                                    'description' => '2'
                                },
                                'deleted' => JSON::false,
                                'method' => {
                                    'id' => '58',
                                    'description' => 'Customer Class Is'
                                },
                                'id' => '265',
                                'enabled' => JSON::false
                            },
                            'method_id' => '58',
                            'value' => '2',
                            'operator_id' => '1',
                            'deleted' => JSON::false,
                            'condition_id' => '265',
                            'enabled' => JSON::false
                        },
                ],
              'status_id' => undef,
              'enabled' => JSON::true
            }]
        },
        output => {
            'ruleset' => [
            {
               'sequence' => 5,
               'name' => 'ssasa',
               'channel' => {
                   'id' => '',
                   'description' => ''
                },
               'deleted' => JSON::true,
               'end' => {
                    'hour' => '',
                    'minute' => '',
                    'date' => ''
               },
               'ok' => 0,
               error_msg => [  "Error1", "error2"],
               'action' => {
                    'id' => '1',
                    'description' => 'Credit Hold'
               },
               'idx' => 5,
               'id' => '287',
               'conditions' => [
                 {
                    'ok' => 1,
                    'operator' => {
                        'id' => '1',
                        'description' => 'Equal To'
                     },
                    'error_msg' => [ 'Conditions has error'],
                    'value' => {
                        'id' => '2',
                        'description' => '2'
                    },
                    'deleted' => JSON::false,
                    'method' => {
                        'id' => '58',
                        'description' => 'Customer Class Is'
                    },
                    'id' => '265',
                    'enabled' => JSON::false
                 }
               ],
               'enabled' => JSON::false,
               'start' => {
                    'hour' => '',
                    'minute' => '',
                    'date' => ''
               }
             }
           ]
        }
      },
      Test4 => {
          input => {
            ruleset => [
                {
                    'end_date' => '',
                    'start_date' => '',
                    'conditions' => [
                        {
                            '_source' => {
                                'operator' => {
                                    'id' => '1',
                                    'description' => 'Equal To'
                                },
                                'value' => {
                                    'id' => '2',
                                    'description' => '2'
                                },
                            },
                            method => 'xyz',
                        }]
                }
            ],
         },
        output => {
            ruleset => [
            {
                'end_date' => '',
                'start_date' => '',
                'conditions' => [
                {
                    ok => 1,
                    error_msg => undef,
                    'operator' => {
                        'id' => '1',
                        'description' => 'Equal To'
                     },
                     'value' => {
                         'id' => '2',
                         'description' => '2'
                     },
                }]
            }
        ]},
     }
    };


    my $got;
    my $expected;
    foreach my $key ( keys %$data ) {
        $expected->{$key}   =  $data->{$key}->{output};
        $got->{$key}        = XT::FraudRules::Actions::Staging::prepare_data_for_output( $data->{$key}->{input});
    }

    is_deeply( $got, $expected, "Test: prepare_data_for_output returns expected results" );
}


sub _get_return_value_type {
    my $self = shift;
    my $type = shift;

    my $return_type_value = $self->schema->resultset('Fraud::ReturnValueType')
        ->search({type => lc($type)})->first;

    return $return_type_value;
}

sub _construct_payload {
    my $self = shift;
    my $type =  shift // 'boolean';
    my $method_id   = shift;


    my $sequence = $self->schema->resultset('Fraud::StagingRule')->get_column('rule_sequence')->max // 0;
    $sequence++;

    # get me  return type for boolean
    my $return_type_value = $self->_get_return_value_type($type);
    my $method;

    if($method_id ) {
        $method = $self->schema->resultset('Fraud::Method')->find($method_id);
    } else {
        $method =  $self->schema->resultset('Fraud::Method')
            ->search({'return_value_type_id' => $return_type_value->id })
            ->first;
    }
    my $operator = $method->return_value_type->link_return_value_type__conditional_operators->first;

    my %values = (
        boolean     => 'true',
        string      => 'Random string',
        integer     => 100,
        decimal     => 2.00,
        dbid        => 1,
    );

    my $value = $values{$type};
    my $channel = $self->schema->resultset('Public::Channel')->first;

    my $payload = [
    {
        id => '',
        name => "Test Rule Name- $sequence",
        status => $FRAUD_RULE_STATUS__CHANGED,
        sequence => $sequence,
        deleted => JSON::false,
        enabled => JSON::true,
        channel => {
            id => $channel->id,
            description => '',
        },
        start => {
            date => '',
            hour => '',
            minute => '',
        },
        end => {
            date => '',
            hour => '',
            minute => '',
        },
        action => {
            id => $ORDER_STATUS__CREDIT_HOLD,
            description => '',
        },
        tags => [],
        conditions => [
        {
            id => '',
            enabled => JSON::true,
            deleted => JSON::false,
            method => {
                id => $method->id,
                description => '',
            },
            operator => {
                id => $operator->conditional_operator_id,
                description => '',
            },
            value => {
                id =>  $value,
                descrption => '',
            },

        }],

    }];

    return $payload;

}

sub _get_method {
    my ( $self, $return_type_id )   = @_;

    return $self->schema->resultset('Fraud::Method')
        ->search( { return_value_type_id  => $return_type_id })
        ->first;

}

sub _get_class {
    my $self    = shift;
    my $payload = shift;

    my $class_obj    = XT::FraudRules::Actions::Staging->new({
        schema => $self->{schema},
        action => 'save',
        force_commit => JSON::true,
        ruleset_json => $payload,
    });


    return $class_obj;

}

sub test_shutdown : Test( shutdown => 0 ) {
    my $self = shift;

    $self->{schema}->txn_rollback;

}

=head2 test_pull_from_live

Make sure that when we pull live data from staging, all the data is copied
correctly into the staging table and the live and archived tables have not
been touched.

=cut

sub test_pull_from_live : Tests {
    my $self = shift;

    # Get a new XT::FraudRules::Actions::Staging object.
    my $object = $self->object;

    # Clear all the rules/conditions.
    $self->discard_all_rules;

    # Before we do the main tests, we need to make sure that if there are no
    # rules in live, an error is returned.

    # Call the method.
    my $result_fail = $object->pull_from_live;

    # Check we get the right error.
    is_deeply(
        $result_fail,
        { ok => 0, error_msg => 'There are no rules to copy from live.' },
        'pull_from_live fails when there are no rules in live'
    );

    # Now we can run the main tests.

    # Create some known rules.
    $self->new_rules;

    # Create a live list - 1 is enough to prove this works
    # but to do this we need to create an archived list first
    my $archived_list = Test::XTracker::Data::FraudRule->create_fraud_list('archived', {
        name        => 'Test Pull from Live',
        description => 'a list to be used when testing pull from live',
        list_items  => [ qw/ one two three / ],
        created_by_operator_id  => $APPLICATION_OPERATOR_ID,
        change_log_id           => $self->change_log->search({})->first->id,
    } );

    isa_ok( $archived_list, "XTracker::Schema::Result::Fraud::ArchivedList" );

    my $live_list = Test::XTracker::Data::FraudRule->create_fraud_list('live', {
        name        => 'Test Pull from Live',
        description => 'a list to be used when testing pull from live',
        archived_list_id    => $archived_list->id,
        list_items  => [ qw/ one two three / ],
    } );

    isa_ok( $live_list, "XTracker::Schema::Result::Fraud::LiveList" );

    # Pull from live to staging twice, to make sure it works a second time.
    foreach my $attempt ( 1 .. 2 ) {

        note "Attempt: $attempt";

        # Cache the current rules/conditions.
        my $old = $self->current_rules_and_conditions;

        # Get the current lists and list items
        my $old_lists = $self->current_lists_and_items;

        # Call the method.
        my $result = $object->pull_from_live;

        is_deeply( $result, { ok => 1 }, 'Method pull_from_live succeeded and returned the correct result' );

        # Get the current rules/conditions.
        my $new = $self->current_rules_and_conditions( 'live', 'staging' );

        # Compare the current version with the cached version.
        is_deeply( $new->{staging},  $old->{live}, 'Live has been copied to staging' );
        is_deeply( $new->{live},     $old->{live}, 'Live has not changed' );
        is_deeply( $new->{archived}, $old->{archived}, 'Archived has not changed' );

        # Get the new lists and list items
        my $new_lists = $self->current_lists_and_items;

        # Now make sure that the list id values are correct.
        foreach my $staging_list ( keys %{ $new_lists->{staging} } ) {
            my $live_list = $self->live_lists->search( {
                name => $staging_list,
            } )->first;

            cmp_ok( $new_lists->{staging_list}->{next_list_id}, '==', $live_list->{id},
                "Staging list live_list_id field has correct value" );
        }

        # Make sure staging rules have the correct status.
        cmp_ok( $_->rule_status_id, '==', $FRAUD_RULE_STATUS__UNCHANGED, 'Staging rule ' . $_->name . ' has correct status' )
            foreach $self->staging_rules->all;

    }

}


=head2 test_push_to_live

Make sure that when we push staging data to live, the staging table is not
touched and the following things happen:

    1. Staging data is copied to live.
    2. The archived rules are expired correctly.
    3. The change_log table is populated correctly.
    4. The archived table is populated correctly with all the data from
       staging.

=cut

sub test_push_to_live : Tests {
    my $self = shift;

    my $change_log_description = 'Testing The push_to_live Method';

    # First let's mock XTracker::EmailFunctions so we can test the email notice email
    my $mocked_internal_email = {};

    $self->{mock_send_mail}->mock( 'send_email' => sub {
            $mocked_internal_email->{subject} = $_[3];
            $mocked_internal_email->{body} = $_[4];
            diag "++++++++ I AM IN A MOCKED INTERNAL EMAIL CALL +++++++++";
            return 1;
        }
    );

    # Clear the rules/conditions and create some known ones.
    $self->discard_all_rules;
    $self->new_rules;

    # Get a new XT::FraudRules::Actions::Staging object.
    my $object = $self->object;

    # Before we run the main tests we need to make sure we get an error when
    # trying to push to live with no enabled live rules.

    # Disable all the staging rules.
    $self->staging_rules->update( { enabled => 0 } );

    # Call the method.
    my $result_fail = $object->push_to_live( $APPLICATION_OPERATOR_ID, $change_log_description );

    # Check we get the right error.
    is_deeply(
        $result_fail,
        { ok => 0, error_msg => 'You must have at least one enabled rule to push to live.' },
        'push_to_live fails when there are no enabled rules'
    );

    # Re-enable the rules.
    $self->staging_rules->update( { enabled => 1 } );

    # Create a staging list
    my $staging_list = Test::XTracker::Data::FraudRule->create_fraud_list('staging', {
        name        => 'Test Push to Live',
        description => 'a list to be used when testing push to live',
        list_items  => [ qw/ one two three / ],
    } );

    isa_ok( $staging_list, "XTracker::Schema::Result::Fraud::StagingList" );
    # Now we can run the main tests.

    # Push from staging to live twice, to make sure it works a second time.
    foreach my $attempt ( 1 .. 2 ) {

        note "Attempt: $attempt";

        ## Update all the staging rules to have a slightly different name.
        $_->update( { name => $_->name . " {$attempt}" } )
            foreach $self->staging_rules->all;

        # Cache the current rules/conditions.
        my $old = $self->current_rules_and_conditions;

        # and the current lists
        my $old_lists = $self->current_lists_and_items;
        ok( defined $old_lists->{staging}, "There is a value for old staging lists" );

        # Call the method.
        my $result = $object->push_to_live( $APPLICATION_OPERATOR_ID, $change_log_description );

        is_deeply( $result, { ok => 1 }, 'Method push_to_live succeeded and returned the correct result' );

        ok( $mocked_internal_email->{subject} eq 'CONRAD - New Rules Pushed to Live',
            'Push to live email sent correctly');
        ok( $mocked_internal_email->{body} =~ /$change_log_description/,
            'Push to live email contains correct change log message' );

        # Get the current rules/conditions.
        my $new = $self->current_rules_and_conditions;

        # and the current lists
        my $new_lists = $self->current_lists_and_items;

        # Compare the current version with the cached version.
        is_deeply( $new->{staging},  $old->{staging}, 'Staging has not changed' );
        is_deeply( $new->{live},     $old->{staging}, 'Staging has been copied to live' );

        # Compare the old and new staging and live lists
        ok( defined $new_lists->{live}, "New live list exists" );
        ok( $new_lists->{live}->{'Test Push to Live'}->{id} eq
            $new_lists->{staging}->{'Test Push to Live'}->{next_list_id},
            "The new staging list has the new live list id value" );

        # Remove the id and next_list_id data once it is verified
        foreach my $list ( qw/ live staging / ) {
            delete $new_lists->{$list}->{'Test Push to Live'}->{next_list_id};
            delete $new_lists->{$list}->{'Test Push to Live'}->{id};
        }

        # And check that the lists are identical
        is_deeply( $new_lists->{live}, $new_lists->{staging},
            "New staging and live lists are the same" );

        # As the archived table contains, well, archived data, we can't just check the
        # records match, we need to iterate over all the staging rules and make sure there
        # is a match in the archived table.

        # Keep track of how many rules we match in total.
        my $total_rule_count = 0;

        foreach my $old_staging ( @{ $old->{staging} } ) {

            # Keep track of matches for this rule, there should only be ONE!
            my $rule_count = 0;

            foreach my $new_archived ( @{ $new->{archived} } ) {

                if ( $new_archived->{name} eq $old_staging->{name} ) {
                # We found a match just based on name, now we want to check all the other
                # data matches.

                    is_deeply( $new_archived, $old_staging, "There is an archived record for \"$old_staging->{name}\"" );

                    $rule_count++;
                    $total_rule_count++;

                }
            }

            cmp_ok( $rule_count, '==', 1, "There is only one match for \"$old_staging->{name}\"" );

        }

        cmp_ok( $total_rule_count, '==', scalar @{ $old->{staging} }, 'All the staging rules have a match in the archived table' );

        # Now we've checked all the data has been copied to the right place, we need to
        # check the change_log has been populated correctly and the original rules in the
        # archived table have been expired correctly.

        # Get a ResultSet of all the new archived rows (i.e. exclude the old ones).
        my $new_archived_entries = $self->archived_rules->search( {
            id => { 'not in' => [ map { $_->id } @{ $old->{archived_rs} } ] },
        } );

        # Check the change log table.
        foreach my $new_archived_row ( $new_archived_entries->all ) {

            # Check the description.
            is(
                $new_archived_row->change_log->description,
                $change_log_description,
                'Change log description is correct for "' . $new_archived_row->name . '"'
            );

            # Check the operator ID.
            is(
                $new_archived_row->change_log->operator_id,
                $APPLICATION_OPERATOR_ID,
                'Change log operator ID is correct for "' . $new_archived_row->name . '"'
            );

            # Check the created field is populated.
            ok(
                $new_archived_row->change_log->created,
                'Change log created field is populated for "' . $new_archived_row->name . '"'
            );

        }

        # Check the expiration fields.
        foreach my $archived_row ( @{ $old->{archived_rs} } ) {

            # Reload the records, because they where cached before the method
            # was called.
            $archived_row->discard_changes;

            # Check the expired fields.
            ok( $archived_row->expired, 'Archived entry "' . $archived_row->name . '" has been expired' );
            is(
                $archived_row->expired_by_operator_id,
                $APPLICATION_OPERATOR_ID,
                'Archived entry "' . $archived_row->name . '" has been expired by the correct operator'
            );

        }

        # Check the live_id's in the staging_table are correct and now point to
        # the new live rules. We don't need to do a deep comparison, as this has
        # already been done above.
        foreach my $staging_rule ( $self->staging_rules->all ) {

            ok( $staging_rule->live_rule_id, 'The staging records live_rule_id is not null' );

            is(
                $staging_rule->live_rule->name,
                $staging_rule->name,
                'The staging rule points to the correct live rule "'. $staging_rule->name . '"'
            );

        }

    }

    $self->{mock_send_mail}->unmock('send_email');

}

=head2 test_tags

Test tags are handled correclty.

=cut

sub test_tags : Tests {
    my $self = shift;

    my %tests   = (
        'No tags' => {
            tags => [],
            expected_error => undef,
        },
        'Valid tags' => {
            tags => [ 'tag1', 'tag2' ],
            expected_error => undef,
        },
        'Invalid tags' => {
            tags => [ 'tag, one', 'tag, two' ],
            expected_error => 'Tags cannot contain commas.',
        },
    );

    while ( my ( $name, $test ) = each %tests ) {

        note "Running for '$name'";

        # Get a new payload and set the tags.
        my $payload = $self->_construct_payload;
        $payload->[0]->{tags} = $test->{tags};

        # Call the method.
        my $result = $self
            ->_get_class( $payload )
            ->validate_and_save( 1 );

        if ( $test->{expected_error} ) {

            my $errors = $result->{ruleset}->[0]->{error_msg};

            is( $result->{ok}, 0, 'The payload contains an error' );
            isa_ok( $errors, 'ARRAY', 'The error_msg hash entry' );
            cmp_ok( $errors->[0], 'eq', $test->{expected_error}, 'The correct error message is returned' );

        } else {

            is( $result->{ok} ,1 , "The payload contained no errors");
            diag explain $result
                unless $result->{ok};

            # Check the database has been populated.
            my $rule = $self->staging_rules->first;
            isa_ok( $rule, 'XTracker::Schema::Result::Fraud::StagingRule', 'The new row' );
            isa_ok( $rule->tag_list, 'ARRAY', 'The column tag_list' );
            cmp_deeply( $rule->tag_list, $test->{tags}, 'The tags where saved correctly' );

        }

    }

}

=head2 object

Returns a new XT::FraudRules::Actions::Staging object.

=cut

sub object {
    my $self = shift;

    return XT::FraudRules::Actions::Staging->new( {
        schema => $self->{schema},
    } );

}

=head2 discard_all_rules

Removes all data relating to rules, conditions and log entries.

=cut

sub discard_all_rules {
    my $self = shift;

    # Delete dependencies.
    $self->{schema}->resultset('Fraud::OrdersRuleOutcome')->delete;

    # Delete the Conditions.
    $self->staging_conditions->delete;
    $self->live_conditions->delete;
    $self->archived_conditions->delete;

    # Delete the Rules.
    $self->staging_rules->delete;
    $self->live_rules->delete;
    $self->archived_rules->delete;

    # Delete the List Items
    $self->staging_list_items->delete;
    $self->live_list_items->delete;
    $self->archived_list_items->delete;

    # Delete the Lists
    $self->staging_lists->delete;
    $self->live_lists->delete;
    $self->archived_lists->delete;

    # Delete dependants.
    $self->{schema}->resultset('Fraud::ChangeLog')->delete;

}

=head2 new_rules

Calls C<create_fraud_rule> in L<Test::XTracker::Data::FraudRule> twice to create
both a Live and Staging rule. NOTE: Creating a Live rule also creates an
existing Archived rule.

=cut

sub new_rules {
    my $self = shift;

    Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
        how_many            => 2,
        # Don't create a staging rule.
        auto_create_staging => 0,
        conditions_to_use   => [
            {
                method   => 'Customer is an EIP',
                operator => 'Is',
                value    => 1,
            },
            {
                method   => 'Customer Total Spend over 7 days',
                operator => '=',
                value    => 123.45,
            },
        ],
    } );

    Test::XTracker::Data::FraudRule->create_fraud_rule( 'Staging', {
        how_many          => 2,
        conditions_to_use => [
            {
                method   => 'Order Total Value',
                operator => '>',
                value    => 678.90,
            },
            {
                method   => 'Customer has been credit checked',
                operator => 'Is',
                value    => 1,
            },
        ],
    } );

    # Rename each rule to include a globally unique identifer. This is
    # to help ensure rules have been moved/copied around correctly.
    my $global_identifier = 1;
    $_->update( { name => '[GUID:' . $global_identifier++ . '] ' . $_->name } )
        foreach (
            $self->live_rules->all,
            $self->staging_rules->all,
            $self->archived_rules->all
        );

    return;

}

=head2 current_rules_and_conditions( $source )

Returns a HashRef with two keys for each table, 'table' and 'table_rs', for
example 'staging' and 'staging_rs'.

The 'table' key contains an ArrayRef of HashRefs containing the tables rows
and selected columns to be used for comparison. There is also a 'conditions'
key that contains selected columns for all the conditions.

the 'table_rs' key contains an ArrayRef of DBIx::Class::Row objects for the
table.

=cut

sub current_rules_and_conditions {
    my $self = shift;

    my %result;

    # These are the columns we want to compare.

    my @rule_columns = qw(
        rule_sequence
        id
        action_order_status_id
        channel_id
        enabled
        start_date
        end_date
        metric_decided
        metric_used
        name
        tag_list
    );

    my @condition_columns = qw(
        id
        rule_id
        method_id
        conditional_operator_id
        value
        enabled
    );

    # Make sure all the results are ordered by the same columns.

    my $rule_attributes = {
        columns  => \@rule_columns,
        order_by => \@rule_columns,
    };

    my $condition_attributes = {
        columns  => \@condition_columns,
        order_by => \@condition_columns,
    };

    foreach my $source ( qw( staging live archived ) ) {
    # Get the data for every source.

        # The methods to call on the ResultSets.
        my $rule_method      = "${source}_rules";
        my $condition_method = "${source}_conditions";

        # Get the table data.
        my @data = map {; +{
            $_->get_columns,
            conditions => [
                map {; +{ $_->get_columns } }
                $_->$condition_method->search( undef, $condition_attributes )->all
            ]
        } }
        $self->$rule_method->search( undef, $rule_attributes )->all;

        # Remove the IDs.
        foreach my $rule ( @data ) {
            delete $rule->{id};
            foreach my $condition ( @{ $rule->{conditions} } ) {
                delete $condition->{id};
                delete $condition->{rule_id};
            }
        }

        $result{ $source } = \@data;
        $result{ "${source}_rs" } = [ $self->$rule_method->all ];

    }

    return \%result;

}

=head2 current_lists_and_items

Returns a hashref containing three keys - staging, live and archived - each
of which contains all of the corresponding lists and items.

=cut

sub current_lists_and_items {
    my $self = shift;

    my $lists = {};

    foreach my $table ( qw/ staging live archived / ) {
        my $listname = $table.'_lists';
        foreach my $list ( $self->$listname->all ) {
            $lists->{$table}->{$list->name} = {
                id              => $list->id,
                description     => $list->description,
                items           => [ map { $_->value } $list->list_items->all ],
                # If we're in staging we need the live_list_id. In live we need
                # archived_list_id. In archived there is nothing.
                next_list_id    => $table eq 'archived' ? 0 :
                    $table eq 'live' ? $list->archived_list_id :
                    $list->live_list_id,
            };
        }
    }
    return $lists;
}

=head2 RuleSet helper methods.

The following methods are shortcuts for the related ResultSets:

    * staging_rules
    * staging_conditions
    * live_rules
    * live_conditions
    * archived_rules
    * archived_conditions
    * staging_lists
    * staging_list_items
    * live_lists
    * list_list_items
    * archived_lists
    * archived_list_items

=cut

sub staging_rules       { shift->{schema}->resultset('Fraud::StagingRule')        }
sub staging_conditions  { shift->{schema}->resultset('Fraud::StagingCondition')   }
sub live_rules          { shift->{schema}->resultset('Fraud::LiveRule')           }
sub live_conditions     { shift->{schema}->resultset('Fraud::LiveCondition')      }
sub archived_rules      { shift->{schema}->resultset('Fraud::ArchivedRule')       }
sub archived_conditions { shift->{schema}->resultset('Fraud::ArchivedCondition')  }
sub staging_lists       { shift->{schema}->resultset('Fraud::StagingList')  }
sub staging_list_items  { shift->{schema}->resultset('Fraud::StagingListItem')  }
sub live_lists          { shift->{schema}->resultset('Fraud::LiveList')  }
sub live_list_items     { shift->{schema}->resultset('Fraud::LiveListItem')  }
sub archived_lists      { shift->{schema}->resultset('Fraud::ArchivedList')  }
sub archived_list_items { shift->{schema}->resultset('Fraud::ArchivedListItem')  }
sub change_log          { shift->{schema}->resultset('Fraud::ChangeLog')  }

