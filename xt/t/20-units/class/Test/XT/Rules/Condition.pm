package Test::XT::Rules::Condition;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

use JSON;

=head1 NAME

Test::XT::Rules::Condition

=head1 SYNOPSIS

Tests the various functionality of 'XT::Rules::Condition'

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;
use Test::XT::Data;

use XTracker::Config::Local;
use XTracker::Constants::FromDB     qw( :customer_category );

use XT::Rules::Condition;


# to be done first before ALL the tests start
sub startup : Test( startup => 0 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
}

# to be done BEFORE each test runs
sub setup : Test( setup => 2 ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{data}   = Test::XT::Data->new_with_traits(
        traits  => [
            'Test::XT::Data::Order',
        ],
    );
    $self->{order}      = $self->data->new_order->{order_object};
    $self->{customer}   = $self->{order}->customer;
    $self->{channel}    = $self->{order}->channel;

    $self->schema->txn_begin;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => 0 ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}


=head1 TESTS

=head2 test_build_a_condition

Tests that various uses of Condtion can be built, compiled and evaluated.

=cut

sub test_build_a_condition : Tests() {
    my $self    = shift;

    my %tests   = (
        "A Basic Condition, no Params or Value" => {
            condition   => {
                class => 'Public::Customer',
                method => 'has_finance_watch_flag',
            },
        },
        "A Condition with Scalar Param but no Value" => {
            condition   => {
                class => 'Public::Orders',
                method => 'is_customers_nth_order',
                params => '[ 2 ]',
            },
        },
        "A Condition with Complex Params but no Value" => {
            condition   => {
                class => 'Public::Customer',
                method => 'has_orders_older_than_not_cancelled',
                params => '[ { "count":6, "period":"month" } ]',
            },
        },
        "A Condition with Complex Params one of which is a Place Holder but no Value" => {
            condition   => {
                class => 'Public::Customer',
                method => 'has_orders_older_than_not_cancelled',
                params => '[ { "count":"P[SC.CreditHoldExceptionParams.month:channel]", "period":"month" } ]',
            },
        },
        "A Condition with a Value but no Params" => {
            condition   => {
                class => 'Public::Orders',
                method => 'get_total_value_in_local_currency',
                operator => '>',
                value => 150,
            },
        },
        "A Condition with a Value that's a Place Holder but no Params" => {
            condition   => {
                class => 'Public::Orders',
                method => 'get_total_value_in_local_currency',
                operator => '>',
                value => 'P[LUT.Public::CreditHoldThreshold.value,name=Single Order Value:channel]',
            },
        },
        "A Condition with Params and a Value" => {
            condition => {
                class => 'Public::Customer',
                method => 'total_spend_in_last_n_period',
                params => '[ { "count":7, "period":"day", "on_all_channels":1 } ]',
                operator => '>=',
                value => 123.45,
            },
        },
        "A Condition with a Comma seperated list of Strings as Params" => {
            condition => {
                class => 'Public::Orders',
                method => 'is_in_hotlist',
                params => '[ "String One", "stringTwo", " String Three ", "" ]',
            },
        },
        "A Condition with a Comma seperated list of Numbers as Params" => {
            condition => {
                class => 'Public::Customer',
                method => 'orders_aged',
                params => " [ 1, 4, 54, 0, -1 ] ",
            },
        },
        "A Condition with a String Comparison" => {
            condition => {
                class => 'Public::Orders',
                method => 'get_standard_class_shipment_address_country',
                operator => 'eq',
                value => config_var('DistributionCentre', 'country'),
            },
        },
    );

    # cache that will store both Methods and Place Holder values
    my %cache;

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $condition = $self->new_condition( {
            to_evaluate => $test->{condition},
            channel     => $self->channel,
            objects => [
                $self->customer,
                $self->order,
            ],
            cache       => \%cache,
        } );
        isa_ok( $condition, 'XT::Rules::Condition', "A Condition Object was Created" );
        cmp_ok( $condition->compile, '==', 1, "and could be Compiled" ) or note "Error: \n" . $condition->_dump_error;
        my $got = $condition->evaluate;
        isa_ok( $got, 'XT::Rules::Condition', "'execute' returned '\$self'" );
        cmp_ok( $condition->has_error, '==', 0, "and there was NO error encountered" ) or note "Error: \n" . $condition->_dump_error;
    }

    note "check the Cache";
    ok( exists( $cache{m} ), "Found an entry for Methods in the Cache" );
    ok( exists( $cache{ph} ), "Found an entry for Place Holders in the Cache" );
    cmp_ok(
        scalar( keys %{ $cache{m} } ),
        '>',
        1,
        "Found More than One entry in the Methods Cache"
    );
    cmp_ok(
        scalar( keys %{ $cache{ph} } ),
        '>',
        1,
        "Found More than One entry in the Place Holders Cache"
    );
    #note "---> Dump of Cache: " . p( %cache );
}

=head2 test_different_operator_for_conditions

Will test the different Operators that can be used for Conditions to compare
the result of a Method call against the Value for the Condition.

=cut

sub test_different_operator_for_conditions : Tests() {
    my $self    = shift;

    my $order   = $self->order;
    my $customer= $self->customer;

    # get the values for different functions that are used in the tests
    my $total_value = $order->get_total_value_in_local_currency;
    my $country     = $order->get_standard_class_shipment_address_country;
    # for Boolean Operator
    $customer->update( {
        credit_check => \'now()',
        category_id => $CUSTOMER_CATEGORY__NONE,
    } );

    note "Tests will be done using the following Data:";
    note "       Total Value: '${total_value}'";
    note "       Country    : '${country}'";
    note "       Customer HAS been Credit Checked";
    note "       Customer is NOT an EIP";

    my %tests   = (
        "Test '>' Operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_total_value_in_local_currency',
                operator=> '>',
                value   => $total_value - 10,
            },
            # this value will be used to test that the above condition fails
            value_to_fail => $total_value + 10,
        },
        "Test '>=' Operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_total_value_in_local_currency',
                operator=> '>=',
                # more than one value to test for the Operator
                value   => [
                    $total_value - 10,
                    $total_value,
                ],
            },
            value_to_fail => $total_value + 10,
        },
        "Test '<' Operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_total_value_in_local_currency',
                operator=> '<',
                value   => $total_value + 10,
            },
            value_to_fail => $total_value - 10,
        },
        "Test '<=' Operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_total_value_in_local_currency',
                operator=> '<=',
                # more than one value to test for the Operator
                value   => [
                    $total_value + 10,
                    $total_value,
                ],
            },
            value_to_fail => $total_value - 10,
        },
        "Test '==' Operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_total_value_in_local_currency',
                operator=> '==',
                value   => $total_value,
            },
            value_to_fail => $total_value - 10,
        },
        "Test '!=' Operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_total_value_in_local_currency',
                operator=> '!=',
                value   => $total_value - 10,
            },
            value_to_fail => $total_value,
        },
        "Test 'eq' Operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_standard_class_shipment_address_country',
                operator=> 'eq',
                value   => $country,
            },
            value_to_fail => "${country}${country}",
        },
        "Test 'ne' Operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_standard_class_shipment_address_country',
                operator=> 'ne',
                value   => "${country}${country}",
            },
            value_to_fail => ${country},
        },
        "Test 'boolean' Operator for a TRUE return value" => {
            condition   => {
                class   => 'Public::Customer',
                method  => 'is_credit_checked',
                operator=> 'boolean',
                value   => [ qw(
                    true
                    T
                    Y
                    1
                ) ],
            },
            value_to_fail => 'false',
        },
        "Test 'boolean' Operator for a FALSE return value" => {
            condition   => {
                class   => 'Public::Customer',
                method  => 'is_category_eip',
                operator=> 'boolean',
                value   => [ qw(
                    false
                    F
                    N
                    0
                ) ],
            },
            value_to_fail => 'true',
        },
        "Test when No Value & Operator passed, then a Boolean TRUE is Assumed" => {
            condition   => {
                class   => 'Public::Customer',
                method  => 'is_credit_checked',
            },
        },
        "Test when using 'eval_value' to evalualte a Value before using it in the Condition, will use the '<=' operator" => {
            condition   => {
                class   => 'Public::Orders',
                method  => 'get_total_value_in_local_currency',
                operator=> '<=',
                value   => "${total_value} + 10",
                eval_value => 1,
            },
            value_to_fail => "$total_value - 10",
        },
        "Test 'grep' Operator for a TRUE return value" => {
            condition   => {
                class       => 'Public::Orders',
                method      => 'get_standard_class_shipment_address_country',
                operator    => 'grep',
                value       => qq|["$country","ValidLand","Federation of Stylish States"]|,
                eval_value  => 0,
            },
            value_to_fail   => '["FakeLand","United States of Oblong"]',
        },
        "Test '!grep' Operator for a TRUE return value" => {
            condition   => {
                class       => 'Public::Orders',
                method      => 'get_standard_class_shipment_address_country',
                operator    => '!grep',
                value       => qq|["ValidLand","Federation of Stylish States"]|,
                eval_value  => 0,
            },
            value_to_fail   => qq|["$country","FakeLand","United States of Oblong"]|,
        },
        "Test 'grep' Operator for a TRUE return value with numerical values" => {
            condition   => {
                class       => 'Public::Orders',
                method      => 'get_total_value_in_local_currency',
                operator    => 'grep',
                value       => qq|[${total_value},1,2]|,
                eval_value  => 0,
            },
            value_to_fail   => '[1,2]',
        },
        "Test '!grep' Operator for a TRUE return value with numerical values" => {
            condition   => {
                class       => 'Public::Orders',
                method      => 'get_total_value_in_local_currency',
                operator    => '!grep',
                value       => qq|[1,2]|,
                eval_value  => 0,
            },
            value_to_fail   => qq|[${total_value},1,2]|,
        },
    );

    # this will be used to cache Methods
    my %cache;

    # record all the Methods used in the tests
    # so that the Cache can be checked afterwards
    my %methods_used;

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $value_to_test   = delete $test->{condition}{value};
        my @values          = ( ref( $value_to_test ) ? @{ $value_to_test } : $value_to_test );

        $methods_used{ $test->{condition}{method} } = 1;    # record which method was used

        # Evaluate the Condition foreach of the different
        # Values and check that each PASS the Condition
        note "test the Operator should PASS";
        foreach my $value ( @values ) {
            $test->{condition}{value}   = $value        if ( defined $value );

            note "using Value: '" . ( defined $value ? $value : 'undef' ) . "'";

            my $condition = $self->new_condition( {
                to_evaluate => $test->{condition},
                channel     => $self->channel,
                objects => [
                    $customer,
                    $order,
                ],
                cache       => \%cache,
            } );
            fail( "'compile' had an Error:\n" . $condition->_dump_error )    if ( !$condition->compile );
            my $got = $condition->evaluate;
            cmp_ok( $condition->has_passed, '==', 1, "Condition Passed" );
        }

        # now test that the Condition will Fail
        if ( exists( $test->{value_to_fail} ) ) {
            note "test that the Operator should FAIL using Value: '" . ( defined $test->{value_to_fail} ? $test->{value_to_fail} : 'undef' ) . "'";

            $test->{condition}{value}   = $test->{value_to_fail};
            my $condition = $self->new_condition( {
                to_evaluate => $test->{condition},
                channel     => $self->channel,
                objects => [
                    $customer,
                    $order,
                ],
                cache       => \%cache,
            } );
            fail( "'compile' had an Error")     if ( !$condition->compile );
            my $got = $condition->evaluate;
            cmp_ok( $condition->has_failed, '==', 1, "Condition Failed" );
        }
    }

    note "Check that the Cache was populated";
    ok( exists( $cache{m} ), "Found an entry for Methods in the 'cache'" );
    my $num_methods_used    = scalar( keys %methods_used );
    cmp_ok(
        scalar( keys %{ $cache{m} } ),
        '==',
        $num_methods_used,
        "${num_methods_used} entries were found in the Cache"
    );
}

=head2 test__validate_method

Tests the '_validate' method which makes sure what was passed in to 'to_evaluate' was sane.

=cut

sub test__validate_method : Tests() {
    my $self    = shift;

    my $validate_stage_msg  = qr/Validation/i;

    my %tests   = (
        "Not passing in a 'class'" => {
            to_evaluate => {
                method => 'test'
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/No defined value for.*class/i ),
            },
        },
        "Not passing in a 'method'" => {
            to_evaluate => {
                class => 'test',
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/No defined value for.*method/i ),
            },
        },
        "Passing in a 'value' without an Operator" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'test', value => 34.56,
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/is.*value.*but no.*operator/i ),
            },
        },
        "Passing in 'params' which don't start with an '['" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'test', params => "1",
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/eval.*params/i ),
                exception => re( qr/\w+/i ),
            },
        },
        "Passing in 'params' which don't end in an ']'" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'test', params => "[ 1",
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/eval.*params/i ),
                exception => re( qr/\w+/i ),
            },
        },
        "Passing in 'params' which start with '{' and end with '}'" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'test', params => "{ a:[1] }",
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/eval.*params/i ),
                exception => re( qr/\w+/i ),
            },
        },
        "Passing in a 'class' which isn't a Class of any of the 'objects'" => {
            to_evaluate => {
                class => 'Public::DoesNotExist', method => 'test',
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/class.*used.*does not match/i ),
            },
        },
        "Passing in an 'operator' which perl can't understand" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'test', operator => '"', value => 234,
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/eval.*operator/i ),
                exception => re( qr/\w+/i ),
            },
        },
        "Passing in a comment (#) as an 'operator'" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'test', operator => '#', value => 234,
            },
            expected_error => {
                stage   => re( $validate_stage_msg ),
                message => re( qr/eval.*operator/i ),
                exception => re( qr/\w+/i ),
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $obj = $self->new_condition( {
            to_evaluate => $test->{to_evaluate},
            channel     => $self->channel,
            objects =>[
                $self->order,
                $self->customer,
            ]
        } );
        isa_ok( $obj, 'XT::Rules::Condition', "Got an Object" );

        cmp_ok( $obj->_validate, '==', 0, "'_validate' method returns FALSE" );
        cmp_deeply( $obj->error, $test->{expected_error}, "and 'error' is set as expected" );
    }
}

=head2 test_values_for_conditions

Tests Values that are passed in are acceptable and don't allow any harmful CODE injections.

=cut

sub test_values_for_conditions : Tests() {
    my $self    = shift;

    my $stage_msg   = qr/Transforming Value/i;

    my %tests   = (
        "Passing in an Invalid Boolean 'value'" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => 'boolean', value => '345.54',
            },
            to_compile => 0,
            expected_error => {
                stage   => re( $stage_msg ),
                message => re( qr/operator is.*boolean.*value.*not.*acceptable/i ),
            },
        },
        "Passing in CODE Injection as a 'value' and asking to evaluate it" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => 'eq', value => 'system("echo", "Hello World!")', eval_value => 1,
            },
            to_compile => 0,
            expected_error => {
                stage   => re( $stage_msg ),
                message => re( qr/couldn't.*eval.*value/i ),
                exception => re( qr/.+/ ),
            },
        },
        "Passing in a 'value' which is a simple String and asking to evaluate it" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => '>', value => "HelloWorld", eval_value => 1,
            },
            to_compile => 0,
            expected_error => {
                stage   => re( $stage_msg ),
                message => re( qr/couldn't.*eval.*value/i ),
                exception => re( qr/.+/ ),
            },
        },
        "Passing in a 'value' with a simple addition to be evaluated" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => '>', value => '100 + 10', eval_value => 1,
            },
            to_compile => 1,
            expected_value => 110,
        },
        "Passing in a 'value' with a simple subtraction to be evaluated" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => '>', value => '100 - 10', eval_value => 1,
            },
            to_compile => 1,
            expected_value => 90,
        },
        "Passing in a 'value' with a simple multiplication to be evaluated" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => '>', value => '100 * 10', eval_value => 1,
            },
            to_compile => 1,
            expected_value => 1000,
        },
        "Passing in a 'value' with a simple division to be evaluated" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => '>', value => '100.50 / 2', eval_value => 1,
            },
            to_compile => 1,
            expected_value => 50.25,
        },
        "Passing in a 'value' which is a decimal" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => '>', value => 123.45,
            },
            to_compile => 1,
            expected_value => 123.45,
        },
        "Passing in a 'value' which is a string" => {
            to_evaluate => {
                class => 'Public::Customer', method => 'is_an_eip',
                operator => '>', value => "Hello World!",
            },
            to_compile => 1,
            expected_value => "Hello World!",
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $obj = $self->new_condition( {
            to_evaluate => $test->{to_evaluate},
            channel     => $self->channel,
            objects =>[
                $self->order,
                $self->customer,
            ]
        } );
        isa_ok( $obj, 'XT::Rules::Condition', "Got an Object" );

        my $got = $obj->compile;
        if ( $test->{to_compile} ) {
            cmp_ok( $got, '==', 1, "'compile' method returns TRUE" ) or note "Error:\n" . $obj->_dump_error;
            is( $obj->_parsed_condition->{value}, $test->{expected_value}, "and Parsed Value is as Expected" );
        }
        else {
            cmp_ok( $got, '==', 0, "'compile' method returns FALSE" );
            cmp_deeply( $obj->error, $test->{expected_error}, "and 'error' is set as expected" );
        }
    }
}

=head2 test_has_attributes

Will test that when you set to TRUE one of the following 'has_*' attributes:

    has_passed
    has_failed
    has_error

The others will be set to to FALSE.

=cut

sub test_has_attributes : Tests() {
    my $self    = shift;

    my $condition   = $self->new_condition( {
        to_evaluate => { class => 'Public::Class', method => 'is_an_eip' },
        channel     => $self->channel,
        objects =>[
            $self->order,
            $self->customer,
        ]
    } );

    note "checking Defaults";
    ok( defined $condition->has_error && $condition->has_error == 0, "'has_error' is FALSE" );
    ok( !defined $condition->has_passed, "'has_passed' is 'undef'" );
    ok( !defined $condition->has_failed, "'has_failed' is 'undef'" );

    note "checking the Triggers";
    my %tests   = (
        has_failed  => {
            has_passed  => 0,
            has_error   => 0,
        },
        has_passed  => {
            has_failed  => 0,
            has_error   => 0,
        },
        has_error   => {
            has_passed  => 0,
            has_failed  => 0,
        },
    );

    foreach my $method ( keys %tests ) {
        note "setting '${method}' to TRUE";
        $condition->$method( 1 );
        cmp_ok( $condition->$_, '==', 0, "sets '${_}' to FALSE" )
                                foreach ( keys %{ $tests{ $method } } );
        # test setting the OTHER Methods to FALSE
        # doesn't trigger THIS Method to be FALSE
        foreach my $other_method ( keys %{ $tests{ $method } } ) {
            note "setting '${other_method}' to FALSE";
            $condition->$other_method( 0 );
            cmp_ok( $condition->$method, '==', 1, "DOESN'T set '${method}' to being FALSE" );
        }
    }
}

=head2 test__replace_place_holders

This tests the to '_replace_place_holder' method to make sure
Place Holders get processed.

=cut

sub test__replace_place_holders : Tests() {
    my $self    = shift;

    # just get an instance of 'XT::Rules::Condition'
    # so that can the '_replace_place_holders' method can be called
    my $condition   = $self->new_condition( {
        to_evaluate => { class => 'Public::Customer', method => 'test_method' },
        objects => [
            $self->order,
        ],
        # by not passing a Sales Channel the
        # 'channel' on '$self->order' will be used
    } );

    # set-up a test System Config group
    Test::XTracker::Data->remove_config_group( 'TestGroup', $self->channel );
    Test::XTracker::Data->create_config_group( 'TestGroup', {
        channel  => $self->channel,
        settings => [ { setting => 'Test Setting', value => 8 } ],
    } );

    # get values that for some place holders
    my $email_address   = config_var(
        'Email_' . $self->channel->business->config_section,
        'customercare_email'
    );
    my $dc_name         = config_var('DistributionCentre','name');

    my %tests   = (
        "System Config Place Holder, Channelised" => {
            string  => 'P[SC.TestGroup.Test Setting:channel]',
            expected=> '8',
        },
        "Normal Config Place Holder, Not Channelised" => {
            string  => 'P[C.DistributionCentre.name]',
            expected=> $dc_name,
        },
        "Normal Config Place Holder, Channelised" => {
            string  => 'P[C.Email.customercare_email:channel]',
            expected=> $email_address,
        },
        "Multiple Occurences of Place Holders" => {
            string  => "P[SC.TestGroup.Test Setting:channel] 'P[C.DistributionCentre.name]' P[C.Email.customercare_email:channel]",
            expected=> "8 '${dc_name}' ${email_address}",
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test = $tests{ $label };

        my $got = $condition->_replace_place_holders( $test->{string} );
        is( $got, $test->{expected}, "Place Holders were replaced correctly: '${got}'" );
    }
}

sub test_json_decode : Tests {
    my $self = shift;

    my $json = JSON->new->utf8;

    my %cache;

    my $condition = $self->new_condition( {
        to_evaluate => {
            class       => 'Public::Orders',
            method      => 'get_standard_class_shipment_address_country',
            operator    => '!grep',
            value       => qq|["ValidLand","Federation of Stylish States"]|,
            eval_value  => 0,
        },
        channel     => $self->channel,
        objects => [
            $self->customer,
            $self->order,
        ],
        cache       => \%cache,
    } );

    my %tests = (
        array_ref   => [ qw(
            SomeValue
            Another
            YetAnotherPointlessValue
        ) ],
        hash_ref    => {
            key1    => 'Value 1',
            key2    => 'Value 2',
            aref    => [ qw(
                Value3
                Value4
                Value5
                ) ],
        },
    );

    while( my ( $test_name, $data ) = each %tests ) {
        note "Testing $test_name";

        my $encoded = $json->encode($data);
        my $decoded = $condition->_json->utf8->decode($encoded);

        is_deeply($data, $decoded, "Decoded data is the same as original");
    }
}

#-------------------------------------------------------------------------

sub data {
    my $self    = shift;
    return $self->{data};
}

sub channel {
    my $self    = shift;
    return $self->{channel};
}

sub order {
    my $self    = shift;
    return $self->{order};
}

sub customer {
    my $self    = shift;
    return $self->{customer};
}

# get an instance of the
# XT::Rules::Condition
sub new_condition {
    my ( $self, $args )     = @_;
    return XT::Rules::Condition->new( $args );
}

