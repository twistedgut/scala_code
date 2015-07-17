#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head2 Use of Fraud Rules Engine

Tests the use of the Fraud Rules Engine in the Order Importer based on the different Switch settings:

    * Switched 'On'          - Fraud Rules Engine is used
    * Switched 'Off'         - Old Rules are used
    * Swithced to 'Parallel' - Old Rules are used but a Job is placed on the
                               Job Queue to run the Fraud Rules Engine in Parallel

Will also test the scenario when the Fraud Rules Engine is switched 'On' but it dies
and the Old Rules are then used.

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::PreOrder;
use Test::XTracker::Data::FraudRule;
use Test::XT::Data;
use Test::XT::DC::JQ;

use XTracker::Config::Local         qw( config_var );
use XTracker::Constants::FromDB     qw(
                                        :fraud_rule_outcome_status
                                        :order_status
                                        :pre_order_status
                                        :pre_order_item_status
                                    );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $amq         = Test::XTracker::MessageQueue->new;
my $queue_name  = config_var('Producer::DCQuery::FraudQuery', 'routes_map')->{outbound_query_queue};

# get a Test Job Queue
my $jq  = Test::XT::DC::JQ->new;

# needed so that some config options can be changed
my $config  = \%XTracker::Config::Local::config;

$schema->txn_do( sub {

    my $data = Test::XT::Data->new_with_traits(
        traits => [
            'Test::XT::Data::Channel',      # should default to NaP
            'Test::XT::Data::Customer',
        ],
    );

    my $channel = $data->channel;
    my $customer= $data->customer;
    $customer->update( { account_urn => 'test:urn' } );

    no warnings "redefine";
    # this effects whether an Order goes on Hold or Not
    my $fraud_rules_credit_rating   = 1000;     # Order would be Accepted
    ## no critic(ProtectPrivateVars)
    *XT::Data::Order::_process_fraud_exception = sub { return $fraud_rules_credit_rating; };
    # this makes sure that an Order on Hold would always want to send a Request to another DC
    *XTracker::Schema::Result::Public::Orders::has_only_order_count_order_flags = sub { return 1; };
    use warnings "redefine";

    my ( $forget, $pids ) = Test::XTracker::Data->grab_products( {
        how_many            => 1,
        dont_ensure_stock   => 1,
        channel             => $channel,
    } );
    my $sku = $pids->[0]{sku};

    my %tests   = (
        "Testing with Fraud Rules Engine Switched Off" => {
            engine_switch           => 'Off',
            fraud_check_order_status=> 'Accepted',
            enable_remote_dc_query  => 0,
            expect  => {
                order_outcome_created => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created   => 0,
            },
        },
        "Testing with Fraud Rules Engine Switched Off, Order 'Accepted', Call to Remote DC is Switched On, Remote DC Call is NOT made" => {
            engine_switch           => 'Off',
            fraud_check_order_status=> 'Accepted',
            enable_remote_dc_query  => 1,
            expect  => {
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 0,
            },
        },
        "Testing with Fraud Rules Engine Switched to Parallel" => {
            engine_switch           => 'Parallel',
            fraud_check_order_status=> 'Accepted',
            enable_remote_dc_query  => 0,
            expect  => {
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 1,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 0,
            },
        },
        "Testing when Fraud Rules Engine Switched to Parallel and Order is for a Pre-Order, No Job Created" => {
            engine_switch           => 'Parallel',
            fraud_check_order_status=> 'Credit Hold',
            enable_remote_dc_query  => 0,
            create_preorder_order   => 1,
            expect  => {
                order_status            => 'Accepted',
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 0,
            },
        },
        "Testing with Fraud Rules Engine Switched On" => {
            engine_switch           => 'On',
            fraud_check_order_status=> 'Accepted',
            enable_remote_dc_query  => 0,
            expect  => {
                order_outcome_created   => 1,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 1,
                },
                amq_message_created     => 0,
            },
        },
        "Testing with Fraud Rules Engine Switched On, Order 'Accepted', Call to Remote DC is Switched On, Remote DC Call is NOT made" => {
            engine_switch           => 'On',
            fraud_check_order_status=> 'Accepted',
            enable_remote_dc_query  => 1,
            expect  => {
                order_outcome_created   => 1,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 1,
                },
                amq_message_created     => 0,
            },
        },
        "Testing when Fraud Rules Engine Switched On and Order is for a Pre-Order, Order is 'Accepted'" => {
            engine_switch           => 'On',
            fraud_check_order_status=> 'Credit Hold',
            enable_remote_dc_query  => 0,
            create_preorder_order   => 1,
            expect  => {
                order_status            => 'Accepted',
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 0,
            },
        },
        "Testing when Fraud Rules Engine Switched Off and Order Put On Hold, Remote DC Call is made" => {
            engine_switch           => 'Off',
            fraud_check_order_status=> 'Credit Hold',
            enable_remote_dc_query  => 1,
            expect  => {
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 1,
            },
        },
        "Testing when Fraud Rules Engine Switched Off, Order Put On Hold, Call to Remote DC is Switched Off, Remote DC Call is NOT made" => {
            engine_switch           => 'Off',
            fraud_check_order_status=> 'Credit Hold',
            enable_remote_dc_query  => 0,
            expect  => {
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 0,
            },
        },
        "Testing when Fraud Rules Engine Switched On and Order Put On Hold, Remote DC Call is made" => {
            engine_switch           => 'On',
            fraud_check_order_status=> 'Credit Hold',
            enable_remote_dc_query  => 1,
            expect  => {
                order_outcome_created   => 1,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 1,
                },
                amq_message_created     => 1,
            },
        },
        "Testing when Fraud Rules Engine Switched On, Order Put On Hold, Call to Remote DC is Switched Off, Remote DC Call is NOT made" => {
            engine_switch           => 'On',
            fraud_check_order_status=> 'Credit Hold',
            enable_remote_dc_query  => 0,
            expect  => {
                order_outcome_created   => 1,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 1,
                },
                amq_message_created     => 0,
            },
        },
        "Testing with Fraud Rules Engine Switched to Parallel and Order Put On Hold, Remote DC Call is made" => {
            engine_switch           => 'Parallel',
            fraud_check_order_status=> 'Credit Hold',
            enable_remote_dc_query  => 1,
            expect  => {
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 1,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 1,
            },
        },
    );

    # these should ALWAYS be done after the above because a
    # key method is re-defined which would fail the above tests
    my %die_tests   = (
        "ENGINE SHOULD DIE - with Fraud Rules Engine Switched On, OLD Rules are Applied, Expect Order to be 'Accepted'" => {
            ENGINE_SHOULD_DIE       => 1,
            engine_switch           => 'On',
            fraud_check_order_status=> 'Accepted',
            enable_remote_dc_query  => 0,
            expect  => {
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 0,
            },
        },
        "ENGINE SHOULD DIE - with Fraud Rules Engine Switched On, OLD Rules are Applied, Expect Order to be on 'Credit Hold' and Calls Remote DC" => {
            ENGINE_SHOULD_DIE       => 1,
            engine_switch           => 'On',
            fraud_check_order_status=> 'Credit Hold',
            enable_remote_dc_query  => 1,
            expect  => {
                order_outcome_created   => 0,
                schwartz_job_created  => {
                    parallel_apply_rules_job      => 0,
                    update_fraud_rule_metrics_job => 0,
                },
                amq_message_created     => 1,
            },
        },
    );

    foreach my $label ( ( keys %tests, keys %die_tests ) ) {
        my $test    = $tests{ $label } // $die_tests{ $label };
        my $expect  = $test->{expect};

        # Expected Order Status should be the same as what the
        # Fraud Checking has been told to do unless explicitly specified
        $expect->{order_status}     //= $test->{fraud_check_order_status};
        $expect->{order_status_rec}   = $schema->resultset('Public::OrderStatus')->find( {
            status => $expect->{order_status},
        } );

        subtest $label => sub {
            $config->{DCQuery}{query_enabled}   = $test->{enable_remote_dc_query};
            _flip_switch( $channel, $test->{engine_switch} );

            # make sure that either way of applying the Fraud Rules gives the result wanted
            _create_fraud_rule( $channel, $test->{fraud_check_order_status} );   # for the NEW
            $fraud_rules_credit_rating  = ( # for the OLD
                $test->{fraud_check_order_status} eq 'Accepted'
                ? 1000      # Order will be Accepted
                : -1000     # Order will be put on Credit Hold
            );

            # once this is set-up it can't be undone which is
            # why the 'die_tests' should be done last
            if ( $test->{ENGINE_SHOULD_DIE} ) {
                # get the Fraud Rules Engine to die
                no warnings "redefine";
                *XT::FraudRules::Engine::apply_rules    = sub { die "TEST EXCEPTION"; };
                use warnings "redefine";
            }

            # clear queues
            $amq->clear_destination( $queue_name );
            $jq->clear_ok;

            # process the Order
            my $data_order  = _create_data_order_to_digest( $test, $pids, $customer );
            my $order       = $data_order->digest( { skip => 1 } );

            cmp_ok( $order->order_status_logs->count, '==', 1, "an Order Status Log has been created" );
            cmp_ok( $order->order_status_id, '==', $expect->{order_status_rec}->id,
                                        "and it's for the Correct Status: '" . $expect->{order_status_rec}->status . "'" );

            if ( $expect->{order_outcome_created} ) {
                my $outcome = $order->orders_rule_outcome;
                ok( defined $outcome, "'orders_rule_outcome' record created for Order" );
                cmp_ok( $outcome->rule_outcome_status_id, '==', $FRAUD_RULE_OUTCOME_STATUS__APPLIED_TO_ORDER,
                                "and Status of Outcome record is 'Applied to Order'" );
            }
            else {
                ok( !defined $order->orders_rule_outcome, "No 'orders_rule_outcome' record created" );
            }

            _check_for_schwartz_job(
                'XT::JQ::DC::Receive::Order::ApplyFraudRules',
                {   # payload
                    order_number => $order->order_nr,
                    channel_id   => $order->channel_id,
                    mode         => 'parallel',
                },
                $expect->{schwartz_job_created}{parallel_apply_rules_job},
                "Job to run the Fraud Rules Engine in Parallel found on Queue",
            );

            my $job_tag = $order->order_nr;
            _check_for_schwartz_job(
                'XT::JQ::DC::Receive::Fraud::UpdateFraudRuleMetrics',
                {   # payload
                    job_tag                      => re( qr/${job_tag}/ ),
                    decisioning_archived_rule_id => ignore(),
                    archived_rule_ids_used       => ignore(),
                },
                $expect->{schwartz_job_created}{update_fraud_rule_metrics_job},
                "Job to Update the Fraud Rule Metrics found on Queue",
            );

            if ( $expect->{amq_message_created} ) {
                $amq->assert_messages({
                    destination => $queue_name,
                    assert_header => superhashof({
                        type => 'dc_fraud_query',
                    }),
                    assert_body => superhashof({
                        account_urn => $customer->account_urn
                    })
                }, "1 and only 1 AMQ Message to Query another Remote DC is sent on: '${queue_name}' queue" );
            }
            else {
                $amq->assert_messages({
                    destination => $queue_name,
                    assert_count => 0,
                }, "no AMQ Messages Query another DC was sent on '${queue_name}' queue" );
            }
        };
    }


    # rollback changes
    $schema->txn_rollback;
} );

# just remove any remaining Order XML Files
Test::XTracker::Data::Order->purge_order_directories();

# clear queues
$amq->clear_destination( $queue_name );
$jq->clear_ok;

done_testing;

#-----------------------------------------------------------------------------

sub _flip_switch {
    my ( $channel, $position )  = @_;

    Test::XTracker::Data->remove_config_group( 'Fraud Rules', $channel );
    Test::XTracker::Data->create_config_group( 'Fraud Rules', {
        channel     => $channel,
        settings    => [
            { setting => 'Engine', value => $position },
        ],
    } );

    return;
}

sub _create_fraud_rule {
    my ( $channel, $type )  = @_;

    Test::XTracker::Data::FraudRule->delete_fraud_rules;
    Test::XTracker::Data::FraudRule->create_live_rule_set( [ {
        channel                 => $channel,
        rule_action_status_id   => (
            $type eq 'Accepted'
            ? $ORDER_STATUS__ACCEPTED
            : $ORDER_STATUS__CREDIT_HOLD
        ),
        condition   => {
            method  => 'Order Total Value',
            operator=> '>=',
            value   => 0,
        },
    } ] );

    return;
}

sub _create_data_order_to_digest {
    my ( $test, $pids, $customer )  = @_;

    my $channel = $customer->channel;

    my $pre_order;
    if ( $test->{create_preorder_order} ) {
        $pre_order  = Test::XTracker::Data::PreOrder->create_complete_pre_order( {
            customer                => $customer,
            variants                => [ $pids->[0]{variant} ],
            pre_order_status        => $PRE_ORDER_STATUS__EXPORTED,
            pre_order_item_status   => $PRE_ORDER_ITEM_STATUS__EXPORTED,
        } );
    }

    # Create and Parse an Order File
    my ( $data_order ) = Test::XTracker::Data::Order->create_order_xml_and_parse( [ {
        customer    => { id => $customer->is_customer_number },
        order       => {
            channel_prefix  => $channel->business->config_section,
            ( $pre_order ? ( preorder_number => $pre_order->pre_order_number ) : () ),
            items   => [ {
                sku         => $pids->[0]->{sku},
                description => $pids->[0]->{product}->product_attribute->name,
                unit_price  => 691.30,
                tax         => 48.39,
                duty        => 0.00
            } ],
        },
    } ] );

    return $data_order;
}

sub _check_for_schwartz_job {
    my ( $worker, $payload, $expect_job, $msg ) = @_;

    if ( $expect_job ) {
        $jq->has_job_ok( {
            funcname => $worker,
            payload  => $payload,
        }, $msg );
    }
    else {
        $jq->does_not_have_job_ok( {
            funcname => $worker,
        }, "NO Job for Worker: '${worker}' found on the Queue" );
    }

    return;
}

