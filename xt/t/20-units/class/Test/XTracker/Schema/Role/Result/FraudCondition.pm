package Test::XTracker::Schema::Role::Result::FraudCondition;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Schema::Role::Result::FraudCondition

=head1 SYNOPSIS

=head1 TESTS

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;

use XTracker::Constants::FromDB         qw( :shipment_type :customer_class );

use JSON;


# to be done first before ALL the tests start
sub startup : Test( startup => 0 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema}     = Test::XTracker::Data->get_schema;
}

# to be done BEFORE each test runs
sub setup : Test( setup => 0 ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->{methods}    = {
        map { $_->description => $_ }
                    $self->rs('Fraud::Method')->all
    };
    $self->{operators}  = {
        map { $_->perl_operator // 'boolean' => $_ }
                    $self->rs('Fraud::ConditionalOperator')->all
    };

    $self->schema->txn_begin;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => 0 ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}

=head2 test_by_processing_cost

Tests that the Result Set method 'by_processing_cost' returns a set of Conditions
in the order of their Method's 'processing_cost' field.

=cut

sub test_by_processing_cost : Tests() {
    my $self    = shift;

    # create one Rule with 7 Conditions
    my ( $rule )    = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', { number_of_conditions => 7 } );

    # contains the different Classes of the Rule
    my %rule_class  = (
        live    => $rule,
        staging => $rule->staging_rules->first,
        archived=> $rule->archived_rule,
    );

    # get the Methods for the Conditions of the Rule
    my @methods = map { $_->method } $rule->live_conditions->all;

    # update the 'processing_cost' of all the Methods
    my $idx = 0;
    foreach my $cost ( 50, 10, 30, 100, 80, 1, 45 ) {
        $methods[ $idx ]->update( { processing_cost => $cost } );
        $idx++;
    }
    my @sorted_methods  = sort { $a->processing_cost <=> $b->processing_cost } @methods;

    # test the Result Set Method brings back the Conditions
    # in the correct order for each Class of Condition
    foreach my $class_type ( qw( staging live archived ) ) {
        my $condition_relationship  = "${class_type}_conditions";
        my @conditions  = $rule_class{ $class_type }
                                ->$condition_relationship
                                    ->by_processing_cost
                                        ->all;
        is_deeply(
            [ map { $_->method_id } @conditions ],
            [ map { $_->id } @sorted_methods ],
            "For '${class_type}' Conditions: Returned in 'processing_cost' order"
        );
    }
}

=head2 test_textualise

Tests the 'textualise' Result method that turns a Condition into English.

=cut

sub test_textualise : Tests() {
    my $self    = shift;

    # specify the Conditions to create and the Expected Textualisation of each
    my @tests   = (
        {
            create_condition    => {
                method      => 'Is Payment Card New for Customer',
                operator    => 'Is',
                value       => '1',
            },
            expected_text       => "Is Payment Card New for Customer is True",
        },
        {
            create_condition    => {
                method      => 'Shipment Type',
                operator    => '=',
                value       => $SHIPMENT_TYPE__DOMESTIC,
            },
            expected_text       => "Shipment Type is equal to 'Domestic'",
        },
        {
            create_condition    => {
                method      => 'Customer Total Spend over 6 months',
                operator    => '>=',
                value       => '8234.45',
            },
            expected_text       => "Customer Total Spend over 6 months is greater than or equal to '8234.45'",
        },
        {
            create_condition    => {
                method      => 'Shipping Address Country',
                operator    => '!=',
                value       => 'Saudi Arabia',
            },
            expected_text       => "Shipping Address Country is not equal to 'Saudi Arabia'",
        },
        {
            create_condition    => {
                method      => 'Payment Card AVS Response',
                operator    => '=',
                value       => 'ALL CHECKED',
            },
            expected_text       => "Payment Card AVS Response is equal to 'ALL CHECKED'",
        },
        {
            create_condition    => {
                method      => 'Has placed any orders in last 1 Month',
                operator    => 'Is',
                value       => '0',
            },
            expected_text       => "Has placed any orders in last 1 Month is False",
        },
    );

    my ( $rule )    = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
        conditions_to_use   => [ map { $_->{create_condition} } @tests ],
    } );

    # get the Conditions for all the Classes of Rules
    my @live_conditions     = $rule->live_conditions->search( {}, { order_by => 'id' } )->all;
    my @staging_conditions  = $rule->staging_rules->first
                                ->staging_conditions->search( {}, { order_by => 'id' } )->all;
    my @archived_conditions = $rule->archived_rule
                                ->archived_conditions->search( {}, { order_by => 'id' } )->all;

    foreach my $idx ( 0..$#tests ) {
        my $expected_text   = $tests[ $idx ]->{expected_text};

        # test each Class of Rule
        my $got_text    = $live_conditions[ $idx ]->textualise;
        like( $got_text, qr/${expected_text}/i, "For 'Live' Condition: Text as Expected: '${got_text}'" );

        $got_text   = $staging_conditions[ $idx ]->textualise;
        like( $got_text, qr/${expected_text}/i, "For 'Staging' Condition: Text as Expected: '${got_text}'" );

        $got_text   = $archived_conditions[ $idx ]->textualise;
        like( $got_text, qr/${expected_text}/i, "For 'Archived' Condition: Text as Expected: '${got_text}'" );
    }
}

=head2 test_compile

Tests the 'compile' Result method that converts the condition into a 'XT::Rules::Condition'
Object so that it can be evaluated later on.

=cut

sub test_compile : Tests() {
    my $self    = shift;

    my $order   = $self->_create_an_order;
    my $channel = $order->channel;
    my $customer= $order->customer;

    my $methods = $self->{methods};
    my $operators = $self->{operators};

    my @tests   = (
        {
            condition   => {
                method  => $methods->{"Number of Orders in last 24 Hours"},
                operator=> $operators->{'>='},
                value   => 3,
            },
        },
        {
            condition   => {
                method  => $methods->{"Shipping Address Country"},
                operator=> $operators->{'=='},
                value   => 'Saudi Arabia',
            },
        },
        {
            condition   => {
                method  => $methods->{"Customer is an EIP"},
                operator => $operators->{'boolean'},
                value   => 0,
            },
        },
        {
            condition   => {
                method  => $methods->{"Order Total Value"},
                operator => $operators->{'<'},
                value   => 450.34,
            },
        },
        {
            condition   => {
                method  => $methods->{"Customer Class"},
                operator => $operators->{'=='},
                value   => $CUSTOMER_CLASS__STAFF,
            },
        },
    );

    my ( $rule )    = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
        channel => $channel,
        conditions_to_use   => [
            map { $_->{condition} } @tests
        ],
    } );

    # get the Conditions for all the Classes of Rules
    my @live    = $rule->live_conditions->search( {}, { order_by => 'id' } )->all;
    my @staging = $rule->staging_rules->first
                        ->staging_conditions->search( {}, { order_by => 'id' } )->all;
    my @archived= $rule->archived_rule
                        ->archived_conditions->search( {}, { order_by => 'id' } )->all;

    my $object_list = [ $order, $customer ];

    foreach my $idx ( 0..$#tests ) {
        my $expected    = $tests[ $idx ]->{condition};

        # test each Class of Rule
        my $got = $live[ $idx ]->compile( $object_list );
        $self->_check_condition( 'Live', $got, $expected );

        $got = $staging[ $idx ]->compile( $object_list );
        $self->_check_condition( 'Staging', $got, $expected );

        $got = $archived[ $idx ]->compile( $object_list );
        $self->_check_condition( 'Archived', $got, $expected );
    }
}

#-------------------------------------------------------------------------

sub _check_condition {
    my ( $self, $description, $got, $expected ) = @_;

    isa_ok( $got, 'XT::Rules::Condition', "For '${description}' Condition: got Compiled" );

    note "checking contents of '_parsed_condition' on the Compiled '${description}' Condition";

    # check out '_parsed_condition' to make sure
    # everytrhing is there that should be
    my $parsed  = $got->_parsed_condition;

    is( $parsed->{method}, $expected->{method}->method_to_call, "Method as Expected" );
    is( $parsed->{operator}, $expected->{operator}->perl_operator // 'boolean',
                        "Operator as Expected" );
    if ( $expected->{method}->is_boolean ) {
        my $boolean = ( $expected->{value} ? 'true' : 'false' );
        like( $parsed->{value}, qr/${boolean}/i, "Value as Expected" );
    }
    else {
        is( $parsed->{value}, $expected->{value}, "Value as Expected" );
    }

    if ( my $params = $expected->{method}->method_parameters ) {
        $params = $self->_json->decode( $params );
        is_deeply( $parsed->{params}, $params, "Parameters as Expected" );
    }
    else {
        ok( !exists( $parsed->{params} ), "No Paramaters found as Expected" );
    }

    return;
}

sub _create_an_order {
    my $self    = shift;

    my $data    = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
        ],
    } );

    my $order_details   = $data->new_order;
    return $order_details->{order_object};
}

sub _json {
    my $self    = shift;

    state $json = JSON->new()->utf8;

    return $json;
}

