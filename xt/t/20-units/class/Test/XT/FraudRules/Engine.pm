package Test::XT::FraudRules::Engine;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XT::FraudRules::Engine

=head1 SYNOPSIS

=head1 TESTS

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;

use Test::XT::Data;
use Test::XT::DC::JQ;

use XT::FraudRules::Engine;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw( :order_status :fraud_rule_outcome_status :shipment_status );

use JSON;


# to be done first before ALL the tests start
sub startup : Test( startup => no_plan ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;

    $self->{json}   = JSON->new()->utf8;

    Test::XTracker::Data::FraudRule->split_live_and_archived_id_sequences();

    # get a list of Conditions to use in creating Rules
    $self->{test_conditions} = Test::XTracker::Data::FraudRule->test_conditions;

    $self->{test_jq} = Test::XT::DC::JQ->new;
    $self->{test_jq}->clear_ok;
}

# to be done BEFORE each test runs
sub setup : Test( setup => no_plan ) {
    my $self = shift;
    $self->SUPER::setup;

    $self->schema->txn_begin;

    $self->{data}   = Test::XT::Data->new_with_traits( {
        traits  => [
            'Test::XT::Data::Order',
        ],
    } );
    $self->{order}  = $self->data->new_order->{order_object};
    $self->{channel}= $self->{order}->channel;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => no_plan ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->{test_jq}->clear_ok;

    $self->schema->txn_rollback;
}

=head2 test_defaults_for_class

=cut

sub test_defaults_for_class : Tests() {
    my $self    = shift;

    my %tests   = (
        "Just Pass an Order only to the Constructor, defaults should be 'live'" => {
            params  => {
                order   => $self->{order},
            },
            expect  => {
                mode        => 'live',
                rule_set    => 'live',
                _rule_rs    => 'XTracker::Schema::ResultSet::Fraud::LiveRule',
                # test methods
                using_staging_rule_set  => 0,
                using_live_rule_set     => 1,
                in_live_mode            => 1,
                in_test_mode            => 0,
                in_parallel_mode        => 0,
                _update_rule_metrics    => 0,
            },
        },
        "Set Rule Set to be for 'staging', Mode should then be 'test'" => {
            params  => {
                order       => $self->{order},
                rule_set    => 'staging',
            },
            expect  => {
                mode        => 'test',
                rule_set    => 'staging',
                _rule_rs    => 'XTracker::Schema::ResultSet::Fraud::StagingRule',
                # test methods
                using_staging_rule_set  => 1,
                using_live_rule_set     => 0,
                in_live_mode            => 0,
                in_test_mode            => 1,
                in_parallel_mode        => 0,
                _update_rule_metrics    => 1,
            },
        },
        "Set Rule Set to be for 'staging' and Mode to be for 'live', Mode should be changed to 'test'" => {
            params  => {
                order       => $self->{order},
                rule_set    => 'staging',
                mode        => 'live',
            },
            expect  => {
                mode        => 'test',
                rule_set    => 'staging',
                _rule_rs    => 'XTracker::Schema::ResultSet::Fraud::StagingRule',
                # test methods
                using_staging_rule_set  => 1,
                using_live_rule_set     => 0,
                in_live_mode            => 0,
                in_test_mode            => 1,
                in_parallel_mode        => 0,
                _update_rule_metrics    => 1,
            },
        },
        "Set Rule Set to be for 'staging' and Mode to be for 'parallel', Mode should be changed to 'test'" => {
            params  => {
                order       => $self->{order},
                rule_set    => 'staging',
                mode        => 'parallel',
            },
            expect  => {
                mode        => 'test',
                rule_set    => 'staging',
                _rule_rs    => 'XTracker::Schema::ResultSet::Fraud::StagingRule',
                # test methods
                using_staging_rule_set  => 1,
                using_live_rule_set     => 0,
                in_live_mode            => 0,
                in_test_mode            => 1,
                in_parallel_mode        => 0,
                _update_rule_metrics    => 1,
            },
        },
        "Set Mode to be for 'parallel', don't specifiy a Rule Set, Rule Set should be 'live' " => {
            params  => {
                order       => $self->{order},
                mode        => 'parallel',
            },
            expect  => {
                mode        => 'parallel',
                rule_set    => 'live',
                _rule_rs    => 'XTracker::Schema::ResultSet::Fraud::LiveRule',
                # test methods
                using_staging_rule_set  => 0,
                using_live_rule_set     => 1,
                in_live_mode            => 0,
                in_test_mode            => 0,
                in_parallel_mode        => 1,
                _update_rule_metrics    => 0,
            },
        },
        "Set Mode to be for 'live', don't specifiy a Rule Set, Rule Set should be 'live' " => {
            params  => {
                order       => $self->{order},
                mode        => 'live',
            },
            expect  => {
                mode        => 'live',
                rule_set    => 'live',
                _rule_rs    => 'XTracker::Schema::ResultSet::Fraud::LiveRule',
                # test methods
                using_staging_rule_set  => 0,
                using_live_rule_set     => 1,
                in_live_mode            => 1,
                in_test_mode            => 0,
                in_parallel_mode        => 0,
                _update_rule_metrics    => 0,
            },
        },
        "Set Mode to be for 'test' and Rule Set to be for 'live'" => {
            params  => {
                order       => $self->{order},
                rule_set    => 'live',
                mode        => 'test',
            },
            expect  => {
                mode        => 'test',
                rule_set    => 'live',
                _rule_rs    => 'XTracker::Schema::ResultSet::Fraud::LiveRule',
                # test methods
                using_staging_rule_set  => 0,
                using_live_rule_set     => 1,
                in_live_mode            => 0,
                in_test_mode            => 1,
                in_parallel_mode        => 0,
                _update_rule_metrics    => 0,
            },
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test    = $tests{ $label };

        my $engine  = XT::FraudRules::Engine->new( $test->{params} );
        isa_ok( $engine, 'XT::FraudRules::Engine', "got an Engine object" );

        # need to check what Class this is
        my $expected_rule_rs    = delete $test->{expect}{_rule_rs};
        isa_ok( $engine->_rule_rs, $expected_rule_rs, "'\$engine->_rule_rs' contains the correct Result Set" );

        while ( my ( $attribute, $value ) = each %{ $test->{expect} } ) {
            is( $engine->$attribute, $value, "'\$engine->${attribute}' has the expected Value: '${value}'" );
        }
    }
}

=head2 test_apply_rules

This will test the method 'apply_rules' to check it Applies them correctly and updates
the Order record depending on which Mode the Engine is ran in.

=cut

sub test_apply_rules : Tests() {
    my $self    = shift;

    my %conditions = %{ $self->{test_conditions} };

    # get all of the Outcome Statuses by Status
    $self->{outcome_status} = {
        map { $_->status => $_->id } $self->rs('Fraud::RuleOutcomeStatus')->all
    };

    # define a few Rule Sets that can be used in the test data below
    my %rules_to_use = (
        "Pass on the Third Rule, which should 'Accept' the Order" => [
            { rule_name => 'Rule 1', rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                        condition => $conditions{"Is Customer's Third Order - TRUE"} },
            { rule_name => 'Rule 2', rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                        condition => $conditions{"Customer is an EIP - TRUE"} },
            { rule_name => 'Rule 3', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                        condition => $conditions{"Number of Orders in last 7 days - <= 3"} },
        ],
        "Pass on the Second Rule, which should 'Credit Hold' the Order" => [
            { rule_name => 'Rule 1', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                        condition => $conditions{"Is Customer's Third Order - TRUE"} },
            { rule_name => 'Rule 2', rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                        condition => $conditions{"Number of Orders in last 7 days - <= 3"} },
            { rule_name => 'Rule 3', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                        condition => $conditions{"Customer is an EIP - TRUE"} },
        ],
        "NO Rules Pass, which should 'Credit Hold' the Order" => [
            { rule_name => 'Rule 1', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                        condition => $conditions{"Is Customer's Third Order - TRUE"} },
            { rule_name => 'Rule 2', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                        condition => $conditions{"Number of Orders in last 7 days - > 3"} },
            { rule_name => 'Rule 3', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                        condition => $conditions{"Customer is an EIP - TRUE"} },
        ],
    );

    my %tests   = (
        "Live Mode: Pass on the Third Rule, which should 'Accept' the Order" => {
            mode    => 'live',
            rules   => $rules_to_use{"Pass on the Third Rule, which should 'Accept' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__ACCEPTED,
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 2,
                applied_to_order   => 1,
                outcome_record  => 1,
                rule_outcome_status => 'Applied to Order',
                number_of_textualisations => 3,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Parallel Mode: Pass on the Third Rule, which should 'Accept' the Order" => {
            mode    => 'parallel',
            rules   => $rules_to_use{"Pass on the Third Rule, which should 'Accept' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__ACCEPTED,
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 2,
                applied_to_order   => 0,
                outcome_record  => 1,
                rule_outcome_status => 'Parallel Expected Outcome',
                number_of_textualisations => 3,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Test Mode: using 'Staging' Rule Set, Pass on the Third Rule, which should 'Accept' the Order" => {
            mode    => 'test',
            rule_set => 'staging',
            rules   => $rules_to_use{"Pass on the Third Rule, which should 'Accept' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__ACCEPTED,
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
                rule_set_used   => 'Staging',
                decisioning_rule_idx => 2,
                applied_to_order   => 0,
                number_of_textualisations => 3,
                outcome_record  => 0,
                metrics_updated => 1,
                can_send_metric_job => 0,
            },
        },
        "Test Mode: using 'Live' Rule Set, Pass on the Third Rule, which should 'Accept' the Order" => {
            mode    => 'test',
            rules   => $rules_to_use{"Pass on the Third Rule, which should 'Accept' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__ACCEPTED,
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 2,
                applied_to_order   => 0,
                number_of_textualisations => 3,
                outcome_record  => 0,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Live Mode: Pass on the Second Rule, which should 'Credit Hold' the Order" => {
            mode    => 'live',
            rules   => $rules_to_use{"Pass on the Second Rule, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 1,
                applied_to_order   => 1,
                number_of_textualisations => 2,
                outcome_record  => 1,
                rule_outcome_status => 'Applied to Order',
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Parallel Mode: Pass on the Second Rule, which should 'Credit Hold' the Order" => {
            start_with  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
            },
            mode    => 'parallel',
            rules   => $rules_to_use{"Pass on the Second Rule, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 1,
                applied_to_order   => 0,
                outcome_record  => 1,
                rule_outcome_status => 'Parallel Expected Outcome',
                number_of_textualisations => 2,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Test Mode: using 'Staging' Rule Set, Pass on the Second Rule, which should 'Credit Hold' the Order" => {
            mode    => 'test',
            rule_set => 'staging',
            rules   => $rules_to_use{"Pass on the Second Rule, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
                rule_set_used   => 'Staging',
                decisioning_rule_idx => 1,
                applied_to_order   => 0,
                number_of_textualisations => 2,
                outcome_record  => 0,
                metrics_updated => 1,
                can_send_metric_job => 0,
            },
        },
        "Test Mode: using 'Live' Rule Set, Pass on the Second Rule, which should 'Credit Hold' the Order" => {
            mode    => 'test',
            rules   => $rules_to_use{"Pass on the Second Rule, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 1,
                applied_to_order   => 0,
                number_of_textualisations => 2,
                outcome_record  => 0,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Live Mode: NO Rules Pass, which should 'Credit Hold' the Order" => {
            mode    => 'live',
            rules   => $rules_to_use{"NO Rules Pass, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => undef,
                applied_to_order   => 1,
                outcome_record  => 1,
                rule_outcome_status => 'Applied to Order',
                number_of_textualisations => 3,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Parallel Mode: NO Rules Pass, which should 'Credit Hold' the Order" => {
            start_with  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
            },
            mode    => 'parallel',
            rules   => $rules_to_use{"NO Rules Pass, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => undef,
                applied_to_order   => 0,
                outcome_record  => 1,
                rule_outcome_status => 'Parallel Expected Outcome',
                number_of_textualisations => 3,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Test Mode: using 'Staging' Rule Set, NO Rules Pass, which should 'Credit Hold' the Order" => {
            mode    => 'test',
            rule_set => 'staging',
            rules   => $rules_to_use{"NO Rules Pass, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                rule_set_used   => 'Staging',
                decisioning_rule_idx => undef,
                applied_to_order   => 0,
                number_of_textualisations => 3,
                outcome_record  => 0,
                metrics_updated => 1,
                can_send_metric_job => 0,
            },
        },
        "Test Mode, Using 'Live' Rule Set, NO Rules Pass, which should 'Credit Hold' the Order" => {
            mode    => 'test',
            rule_set => 'live',
            rules   => $rules_to_use{"NO Rules Pass, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => undef,
                applied_to_order   => 0,
                number_of_textualisations => 3,
                outcome_record  => 0,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Live Mode: 'Accept' Order, with Shipment starting on DDU Hold" => {
            start_with  => {
                order_status_id     => $ORDER_STATUS__ACCEPTED,
                shipment_status_id  => $SHIPMENT_STATUS__DDU_HOLD,
            },
            mode    => 'live',
            rules   => $rules_to_use{"Pass on the Third Rule, which should 'Accept' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__ACCEPTED,
                shipment_status_id => $SHIPMENT_STATUS__DDU_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 2,
                applied_to_order   => 1,
                outcome_record  => 1,
                rule_outcome_status => 'Applied to Order',
                number_of_textualisations => 3,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Live Mode: 'Credit Hold' Order, with Shipment starting on DDU Hold" => {
            start_with  => {
                order_status_id     => $ORDER_STATUS__ACCEPTED,
                shipment_status_id  => $SHIPMENT_STATUS__DDU_HOLD,
            },
            mode    => 'live',
            rules   => $rules_to_use{"Pass on the Third Rule, which should 'Accept' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__ACCEPTED,
                shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 2,
                applied_to_order   => 1,
                outcome_record  => 1,
                rule_outcome_status => 'Applied to Order',
                number_of_textualisations => 3,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Parallel Mode: 'Accept' Order, but is to compare with an Order on 'Credit Hold'" => {
            start_with  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
            },
            mode    => 'parallel',
            rules   => $rules_to_use{"Pass on the Third Rule, which should 'Accept' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__ACCEPTED,
                shipment_status_id => $SHIPMENT_STATUS__PROCESSING,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 2,
                applied_to_order   => 0,
                outcome_record  => 1,
                rule_outcome_status => 'Parallel Unexpected Outcome',
                number_of_textualisations => 3,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Parallel Mode: 'Credit Hold' Order, but is to compare with an Order that's been 'Accepted'" => {
            start_with  => {
                order_status_id => $ORDER_STATUS__ACCEPTED,
            },
            mode    => 'parallel',
            rules   => $rules_to_use{"Pass on the Second Rule, which should 'Credit Hold' the Order"},
            expect  => {
                order_status_id => $ORDER_STATUS__CREDIT_HOLD,
                shipment_status_id => $SHIPMENT_STATUS__FINANCE_HOLD,
                rule_set_used   => 'Live',
                decisioning_rule_idx => 1,
                applied_to_order   => 0,
                outcome_record  => 1,
                rule_outcome_status => 'Parallel Unexpected Outcome',
                number_of_textualisations => 2,
                flags_applied   => 1,
                metrics_updated => 0,
                can_send_metric_job => 1,
            },
        },
        "Live Mode: Pass on a Rule with Unknown Order Action Status: 'Credit Check', Engine Should DIE" => {
            mode    => 'live',
            rules   => [
                { rule_name => 'Rule 1', rule_action_status_id => $ORDER_STATUS__CREDIT_CHECK,
                                        condition => $conditions{'Number of Orders in last 7 days - <= 3'} },
            ],
            expect  => {
                to_die  => 1,
                rule_set_used => 'Live',
            },
        },
        "Live Mode: Pass on a Rule with Unknown Order Action Status: 'Cancelled', Engine Should DIE" => {
            mode    => 'live',
            rules   => [
                { rule_name => 'Rule 1', rule_action_status_id => $ORDER_STATUS__CANCELLED,
                                        condition => $conditions{'Number of Orders in last 7 days - <= 3'} },
            ],
            expect  => {
                to_die  => 1,
                rule_set_used => 'Live',
            },
        },
    );

    my $order   = Test::XTracker::Data::FraudRule->create_order;
    my $shipment= $order->get_standard_class_shipment;
    my $channel = $order->channel;

    TEST:
    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";

        my $test        = $tests{ $label };
        $test->{order}  = $order;

        my $rules       = delete $test->{rules};
        my $expect      = delete $test->{expect};
        my $start_with  = delete $test->{start_with} // {};
        $start_with->{order_status_id}    //= $ORDER_STATUS__ACCEPTED;
        $start_with->{shipment_status_id} //= $SHIPMENT_STATUS__PROCESSING;

        $order->orders_rule_outcome->delete     if ( $order->discard_changes->orders_rule_outcome );
        $order->order_flags->delete;
        Test::XTracker::Data::FraudRule->reset_order_statuses( $order );
        Test::XTracker::Data::FraudRule->delete_fraud_rules;

        # set the Statuses to start with
        if ( $test->{mode} eq 'parallel' ) {
            # for Parallel Mode there needs to be already an Order Status log record
            $order->discard_changes->change_status_to(
                $start_with->{order_status_id},
                _operator_id()
            );
        }
        else {
            $order->update( { order_status_id => $start_with->{order_status_id} } );
        }
        $shipment->discard_changes->update( { shipment_status_id => $start_with->{shipment_status_id} } );
        $expect->{started_with} = $start_with;
        $expect->{mode_used}    = $test->{mode};

        my $rule_set    = Test::XTracker::Data::FraudRule->create_live_rule_set( $rules, $channel );
        my $rules_used  = $rule_set->{ $expect->{rule_set_used} };

        my $engine  = XT::FraudRules::Engine->new( $test );

        if ( $expect->{to_die} ) {
            throws_ok {
                    $engine->apply_finance_flags;
                    $engine->apply_rules;
                }
                qr/Unexpected Order Status/i,
                "Engine Died with expected Exception"
            ;
            next TEST;
        }

        $engine->apply_finance_flags;
        my $status  = $engine->apply_rules;

        isa_ok( $status, 'XTracker::Schema::Result::Public::OrderStatus',
                            "'apply_rules' returned an Order Status object" );
        cmp_ok( $status->id, '==', $expect->{order_status_id}, "and is for the Correct Status" );

        $self->_check_engine_outcome_object( $expect, $rules_used, $engine->outcome, $order );
        $self->_check_orders_rule_outcome_record( $expect, $rules_used, $order, $engine->outcome );
        $self->_check_rule_metrics( $expect, $rules_used, $engine->outcome );
        $self->_check_order_shipment_records( $expect, $order );
    }
}

#-------------------------------------------------------------------------

sub _check_engine_outcome_object {
    my ( $self, $expect, $rules, $outcome, $order ) = @_;

    note "check the 'Engine::Outcome' object";

    my $rule_class  = 'Fraud::' . $expect->{rule_set_used} . 'Rule';

    isa_ok( $outcome->action_order_status, 'XTracker::Schema::Result::Public::OrderStatus',
                        "'action_order_status' contains a Status" );
    cmp_ok( $outcome->action_order_status->id, '==', $expect->{order_status_id}, "and is for the Correct Status" );
    isa_ok( $outcome->flags_assigned_rs, 'XTracker::Schema::ResultSet::Public::Flag',
                        "'flags_assigned_rs' has a ResultSet" );

    if ( $expect->{applied_to_order} ) {
        my @order_flags = map { $_ } $order->discard_changes->order_flags->all;
        cmp_deeply(
            [ sort { $a <=> $b } map { $_->id } $outcome->flags_assigned_rs->all ],
            [ sort { $a <=> $b } map { $_->flag_id } @order_flags ],
            "and is for the correct Flags"
        );
    }

    cmp_ok(
        scalar ( $outcome->all_textualisation_rules ),
        '==',
        $expect->{number_of_textualisations},
        "Number of 'textualistion's as Expected"
    );

    # check the sanity of the Rules and Conditions in the
    # textualisation Structure, there SHOULD be an ID in the
    # Conditions part that shouldn't have been removed after the
    # 'textualisation_to_json' method would have been called
    my $expect_structure = {
        id              => re( qr/^\d+$/ ),
        textualisation  => re( qr/\w+/ ),
        passed          => re( qw/^[01]$/ ),
        conditions      => array_each( {
            id              => re( qr/^\d+$/ ),
            textualisation  => re( qr/\w+/ ),
            passed          => re( qr/^[01]$/ ),
        } ),
    };
    cmp_deeply( $outcome->textualisation, array_each( $expect_structure ),
                        "and each Textualisation Element has the Expected Structure" );

    my $decisioning_rule;
    if ( defined $expect->{decisioning_rule_idx} ) {
        my $idx = $expect->{decisioning_rule_idx};
        isa_ok( $outcome->decisioning_rule, "XTracker::Schema::Result::${rule_class}",
                            "'decisioning_rule' is populated on the Outcome object" );
        cmp_ok( $outcome->decisioning_rule->id, '==', $rules->[ $idx ]->id,
                            "and is for the Expected Rule" );
        cmp_ok( $outcome->has_default_action_been_used, '==', 0,
                            "'has_default_action_been_used' method returns FALSE" );
        $decisioning_rule = $outcome->decisioning_rule;
    }
    else {
        ok( !defined $outcome->decisioning_rule, "No 'decisioning_rule' is defined" );
        cmp_ok( $outcome->has_default_action_been_used, '==', 1,
                            "'has_default_action_been_used' method returns TRUE" );
    }

    # check the 'archived_rule_ids_used' Attribute
    if ( lc( $expect->{rule_set_used} ) eq 'live' ) {
        my $ids = $outcome->archived_rule_ids_used;
        isa_ok( $ids, 'ARRAY', "'archived_rule_ids_used' is an Array" );
        # the number of textualisations should be the same as the number of Ids
        cmp_ok( scalar( @{ $ids } ), '==', $expect->{number_of_textualisations},
                            "and the Array has the expected number of elements" );

        # check the Archived Rule Ids are correct
        my $rule_rs = $self->rs( "XTracker::Schema::Result::${rule_class}" )
                            ->get_active_rules_for_channel( $self->{channel} );
        $rule_rs = $rule_rs->search( {
            rule_sequence => { '<=' => $decisioning_rule->rule_sequence },
        } )     if ( $decisioning_rule );
        my @expect_ids = $rule_rs->get_column('archived_rule_id')->all;
        cmp_deeply( $ids, bag( @expect_ids ), "and the Array has the expected Archived Rule Ids" );
    }
    else {
        ok( !defined $outcome->archived_rule_ids_used,
                        "'archived_rule_ids_used' is 'undef' when NOT using 'live' Rule Set" );
    }

    return;
}

sub _check_orders_rule_outcome_record {
    my ( $self, $expect, $rules, $order, $outcome ) = @_;

    note "check the 'orders_rule_outcome' record";

    if ( $expect->{outcome_record} ) {
        my $order_outcome   = $order->orders_rule_outcome;
        isa_ok( $order_outcome, 'XTracker::Schema::Result::Fraud::OrdersRuleOutcome',
                                    "Order has an 'orders_rule_outcome' record" );
        cmp_ok( $order_outcome->rule_outcome_status_id, '==', $self->{outcome_status}{ $expect->{rule_outcome_status} },
                                    "'rule_outcome_status_id' as Expected: '$expect->{rule_outcome_status}'" );
        if ( defined $expect->{decisioning_rule_idx} ) {
            my $idx = $expect->{decisioning_rule_idx};
            cmp_ok( $order_outcome->archived_rule_id, '==', $rules->[ $idx ]->archived_rule_id,
                                        "'archived_rule_id' is for the Decisioning Rule" );
        }
        else {
            ok( !defined $order_outcome->archived_rule_id, "'archived_rule_id' is 'undef'" );
        }

        my @order_flags = map { $_ } $outcome->flags_assigned_rs->all;
        is(
            $order_outcome->finance_flag_ids,
            join( ',', sort { $a <=> $b } map { $_->id } @order_flags ),
            "'finance_flag_ids' is populated with the correct Ids"
        );

        ok( $order_outcome->textualisation, "'textualisation' has a value" );
        my $array_ref   = $self->{json}->decode( $order_outcome->textualisation );
        isa_ok( $array_ref, 'ARRAY', "and can be JSON decoded into an ArrayRef" );
        cmp_ok( @{ $array_ref }, '==', $expect->{number_of_textualisations}, "and has the Expected number of Elements" );

        # check the sanity of the Rules and Conditions
        # in the structure decoded from the JSON string,
        # there should NOT be an ID in the Conditions part
        my $expect_structure = {
            id              => re( qr/^\d+$/ ),
            textualisation  => re( qr/\w+/ ),
            passed          => re( qw/^[01]$/ ),
            conditions      => array_each( {
                textualisation  => re( qr/\w+/ ),
                passed          => re( qr/^[01]$/ ),
            } ),
        };
        cmp_deeply( $array_ref, array_each( $expect_structure ), "and each Element has the Expected Structure" );
    }
    else {
        ok( !defined $order->orders_rule_outcome, "No 'orders_rule_outcome' record was created for the Order" );
    }

    return;
}

sub _check_rule_metrics {
    my ( $self, $expect, $rules, $outcome ) = @_;

    note "check Rule Metrics were updated";

    my $max_idx     = $expect->{decisioning_rule_idx} // $#{ $rules };
    my $decider_idx = $expect->{decisioning_rule_idx} // -1;    # if no deciding index make it something that can't be reached
    is_deeply(
        [
            map { {
                metric_used     => $_->discard_changes->metric_used,
                metric_decided  => $_->metric_decided,
            } } @{ $rules }[ 0..$max_idx ]
        ],
        [
            map { {
                metric_used     => ( $expect->{metrics_updated} ? 1 : 0 ),
                metric_decided  => ( $expect->{metrics_updated} && $_ == $decider_idx ? 1 : 0 ),
            } } ( 0..$max_idx )
        ],
        "Metric Counters are as Expected"
    );

    my $job_sent = $outcome->send_update_metrics_job('JOB TAG');
    if ( $expect->{can_send_metric_job} ) {
        ok( $job_sent, "Update Metrics Schwartz Job Sent" );
    }
    else {
        ok( !$job_sent, "Update Metrics Schwartz Job NOT Sent" );
    }

    return;
}

sub _check_order_shipment_records {
    my ( $self, $expect, $order )   = @_;

    note "check the Order & Shipment records";

    my $started_with= $expect->{started_with};
    my $shipment    = $order->discard_changes->get_standard_class_shipment;

    if ( $expect->{applied_to_order} ) {
        cmp_ok( $order->order_status_id, '==', $expect->{order_status_id}, "Order Status is as Expected" );
        cmp_ok( $order->order_status_logs->count, '==', 1, "and an Order Status Log record has been created" );

        # check when Shipment Status starts on DDU Hold that it
        # hasn't been changed if the Order has been Accepted
        if ( $expect->{order_status_id} == $ORDER_STATUS__ACCEPTED ) {
            if ( $started_with->{shipment_status_id} == $SHIPMENT_STATUS__DDU_HOLD ) {
                cmp_ok( $shipment->shipment_status_id, '==', $SHIPMENT_STATUS__DDU_HOLD,
                                    "Shipment Status has stayed at 'DDU Hold'" );
            }
            else {
                cmp_ok( $shipment->shipment_status_id, '==', $expect->{shipment_status_id},
                                    "Shipment Status is as Expected" );
            }
            cmp_ok( $shipment->shipment_status_logs->count, '==', 0,
                                    "and No Shipment Status Log record created" );
        }
        else {
            cmp_ok( $shipment->shipment_status_id, '==', $expect->{shipment_status_id},
                                    "Shipment Status is as Expected" );
            cmp_ok( $shipment->shipment_status_logs->count, '==', 1,
                    "and a Shipment Status Log record has been created when Order has been set to Credit Hold" );
        }
    }
    else {
        cmp_ok( $order->order_status_id, '==', $started_with->{order_status_id}, "Order Status is Unchanged" );
        if ( $expect->{mode_used} eq 'parallel' ) {
            # there should be no more than one for Parallel mode
            cmp_ok( $order->order_status_logs->count, '==', 1, "Still only One Order Status Log record has been created" );
        }
        else {
            cmp_ok( $order->order_status_logs->count, '==', 0, "No Order Status Log records have been created" );
        }
        cmp_ok( $shipment->shipment_status_id, '==', $started_with->{shipment_status_id}, "Shipment Status is Unchanged" );
        cmp_ok( $shipment->shipment_status_logs->count, '==', 0, "No Shipment Status Log records have been created" );
    }

    return;
}

sub data {
    my $self    = shift;
    return $self->{data};
}

# create a set of Rules
sub _create_rule_set {
    my ( $self, $rules )    = @_;

    my @live_rules,
    my @staging_rules;

    foreach my $rule ( @{ $rules } ) {
        my $conditions_to_use   = [ delete $rule->{condition} ];
        my $live_rule   = $self->_create_fraud_rule( 'Live', {
            %{ $rule },
            conditions_to_use   => $conditions_to_use,
        } );
        my $staging_rule    = $live_rule->staging_rules->first;

        push @live_rules, $live_rule;
        push @staging_rules, $staging_rule;
    }

    my %rule_set    = (
        Live    => [ sort { $a->rule_sequence <=> $b->rule_sequence } @live_rules ],
        Staging => [ sort { $a->rule_sequence <=> $b->rule_sequence } @staging_rules ],
    );

    return \%rule_set;
}

# return the value of $APPLICATION_OPERATOR_ID constant
sub _operator_id {
    return $APPLICATION_OPERATOR_ID;
}
