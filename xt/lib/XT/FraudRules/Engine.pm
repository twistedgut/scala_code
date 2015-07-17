package XT::FraudRules::Engine;

use NAP::policy "tt", qw( class );

=head1 NAME

XT::FraudRules::Engine

=head1 SYNOPSIS

    use XT::FraudRules::Engine;

    $rules_engine = XT::FraudRules::Engine->new( {
        order       => $orders_obj,
        mode        => 'live',
        rule_set    => 'live',
        # optional
        logger      => $log4perl_obj,
    } );

=head1 DESCRIPTION

Sets the Finance Flags and Runs the Fraud Rules against an Order.

=cut

use Moose::Util::TypeConstraints;

use XTracker::Logfile                   qw( xt_logger );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :flag
                                            :fraud_rule_outcome_status
                                            :order_status
                                            :shipment_status
                                        );

use XT::FraudRules::Type;
use XT::FraudRules::Engine::Outcome;

use XT::Rules::Condition;


=head1 ATTRIBUTES

=cut

has customer => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Customer',
    init_arg    => undef,
    lazy_build  => 1,
);

has order => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Orders',
    init_arg    => 'order',
    required    => 1,
);

has channel => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::Channel',
    init_arg    => undef,
    lazy_build  => 1,
);

has mode => (
    is          => 'rw',
    isa         => 'XT::FraudRules::Type::Mode',
    init_arg    => 'mode',
    default     => 'live',
);

has rule_set => (
    is          => 'ro',
    isa         => 'XT::FraudRules::Type::RuleSet',
    init_arg    => 'rule_set',
    default     => 'live',
    trigger     => sub {
        my $self    = shift;
        $self->mode('test')     if ( $self->using_staging_rule_set );
    },
);

has logger => (
    is          => 'rw',
    isa         => 'Log::Log4perl::Logger',
    lazy_build  => 1,
);

has finance_flags_to_apply => (
    is          => 'ro',
    isa         => 'ArrayRef[HashRef]',
    init_arg    => undef,
    lazy_build  => 1,
    traits      => ['Array'],
    handles     => {
        all_finance_flags   => 'elements',
    },
);

# holds the default Order Status to
# apply to an Order if NO Rule Passes
has _default_action_status => (
    is          => 'ro',
    isa         => 'XTracker::Schema::Result::Public::OrderStatus',
    init_arg    => undef,
    lazy_build  => 1,
);

has _cache => (
    is          => 'ro',
    isa         => 'HashRef',
    init_arg    => undef,
    default     => sub { return {}; },
);

# the Rule ResultSet to use could
# be either 'Fraud::[Staging|Live]Rule'
has _rule_rs => (
    is          => 'ro',
    isa         => 'XT::FraudRules::Type::ResultSet::Rule',
    init_arg    => undef,
    lazy_build  => 1,
);

=head2 schema

DBIC Schema Object.

=cut

has schema => (
    is      => 'ro',
    isa     => 'XTracker::Schema',
    init_arg => undef,
    lazy_build => 1,
);

=head2 outcome

Holds the Outcome of running the Engine, will be an instance of
'XT::FraudRules::Engine::Outcome'.

=cut

has outcome => (
    is      => 'ro',
    isa     => 'XT::FraudRules::Engine::Outcome',
    init_arg => undef,
    lazy_build => 1,
);

=head1 METHODS

=cut

sub using_staging_rule_set { return ( shift->rule_set eq 'staging' ? 1 : 0 ); }
sub using_live_rule_set    { return ( shift->rule_set eq 'live'    ? 1 : 0 ); }

sub in_live_mode     { return ( shift->mode eq 'live'     ? 1 : 0 ); }
sub in_test_mode     { return ( shift->mode eq 'test'     ? 1 : 0 ); }
sub in_parallel_mode { return ( shift->mode eq 'parallel' ? 1 : 0 ); }

=head2 apply_finance_flags

    $self->apply_finance_flags;

Will run through the Finance Flags and actually Apply them if called in 'Live' mode.

Run this before calling 'apply_rules'.

=cut

sub apply_finance_flags {
    my $self    = shift;

    my @flag_rules  = $self->all_finance_flags;

    my @flag_ids_applied;

    FLAG:
    foreach my $flag ( @flag_rules ) {
        # go through all of the Conditions that
        # have to be TRUE for the FLAG to be set
        foreach my $condition_to_evaluate ( @{ $flag->{conditions} } ) {
            my $condition   = $self->_build_condition_obj( $condition_to_evaluate );
            $condition->compile;
            if ( $condition->evaluate->has_failed ) {
                next FLAG;
            }
        }

        # store the Id of the Flag that can be applied
        push @flag_ids_applied, $flag->{flag};

        if ( $self->in_live_mode ) {
            # if it got this far then ALL Conditions should
            # have passed and the Flag can be Added
            my $add_flag_method = (
                $flag->{add_once}
                ? 'add_flag_once'
                : 'add_flag'
            );

            # add the Flag to the Orders object
            $self->order->$add_flag_method( $flag->{flag} );
        }
    }

    $self->outcome->set_flags_assigned( \@flag_ids_applied );

    return;
}

=head2 apply_rules

    $order_status_obj = $self->apply_rules;

This will go through all of the Fraud Rules until one Passes or if none of them pass will
use the default (which is held in the '_default_action_status' attribute).

The 'XT::FraudRules::Engined::Outcome' object will be populated appropriately as the Rules
are being processed and will be available to look at after this method has completed.

If run against the Live Rule Set in either 'Parallel' or 'Live' mode then a
'fraud.orders_rule_outcome' record will be created.

If run in 'Live' mode then the Order's Status will be updated.

This will always return the 'Public::OrderStatus' object for the Status the Rules decided upon.

=cut

sub apply_rules {
    my $self    = shift;

    $self->order->discard_changes;

    my $deciding_rule   = $self->_rule_rs->process_rules_for_channel( $self->channel, {
        cache       => $self->_cache,
        object_list => [
            $self->order,
            $self->customer,
        ],
        outcome     => $self->outcome,
        update_metrics => $self->_update_rule_metrics,
        logger      => $self->logger,
    } );

    my $action_status;
    if ( $deciding_rule ) {
        $self->outcome->decisioning_rule( $deciding_rule );
        $action_status  = $deciding_rule->action_order_status;
    }
    else {
        $action_status  = $self->_default_action_status;
    }
    $self->outcome->action_order_status( $action_status );

    if ( $self->in_live_mode || $self->in_parallel_mode ) {
        # work out the Outcome Status
        my $outcome_status  = $FRAUD_RULE_OUTCOME_STATUS__APPLIED_TO_ORDER;
        $outcome_status     = (
                                $action_status->id == $self->_get_expected_order_status_id
                                ? $FRAUD_RULE_OUTCOME_STATUS__PARALLEL_EXPECTED_OUTCOME
                                : $FRAUD_RULE_OUTCOME_STATUS__PARALLEL_UNEXPECTED_OUTCOME
                            ) if ( $self->in_parallel_mode );

        $self->order->create_related( 'orders_rule_outcome', {
            archived_rule_id        => ( $deciding_rule ? $deciding_rule->archived_rule_id : undef ),
            finance_flag_ids        => $self->outcome->flags_assigned_to_string,
            textualisation          => $self->outcome->textualisation_to_json,
            rule_outcome_status_id  => $outcome_status,
        } );

        # now actually update the Order record to apply the Status
        $self->order->accept_or_hold_order_after_fraud_check( $action_status->id )
                                                                if ( $self->in_live_mode );
    }

    return $action_status;
}

# if run in Parallel Mode this will be called
# to get the Expected Order Status Id
sub _get_expected_order_status_id {
    my $self    = shift;

    # get the First Order Status Log which
    # should be the original Status
    my $log = $self->order->order_status_logs
                            ->search( {}, { order_by => 'me.id' } )
                                ->first;

    my $status_id;
    if ( $log ) {
        $status_id  = $log->order_status_id;
    }
    else {
        # if there is no log then return 0 so that
        # the Outcome Status will be 'Unexpected'
        $status_id  = 0;
    }

    return $status_id;
}

#-----------------------------------------------------------------------------


sub _build_schema {
    my $self    = shift;
    return $self->order->result_source->schema;
}

sub _build_channel {
    my $self    = shift;
    return $self->order->channel;
}

sub _build_customer {
    my $self    = shift;
    return $self->order->customer;
}

sub _build__default_action_status {
    my $self    = shift;
    return $self->schema->resultset('Public::OrderStatus')->find(
        $ORDER_STATUS__CREDIT_HOLD
    );
}

sub _build_logger {
    my $self    = shift;
    return xt_logger();
}

# build the Rule ResultSet to use
# either 'Staging' or 'Live'
sub _build__rule_rs {
    my $self    = shift;

    my $rule_set    = ucfirst( $self->rule_set );
    my $class       = "Fraud::${rule_set}Rule";

    return scalar $self->schema->resultset( $class );
}

sub _build_finance_flags_to_apply {
    my $self    = shift;

    # TODO: Put these in a Database Table!!!!

    my @flags   = (
        { flag => $FLAG__VIRTUAL_VOUCHER, add_once => 1, conditions => [
                { class => 'Public::Orders', method => 'contains_a_virtual_voucher' },
            ],
        },
        { flag => $FLAG__ADDRESS, conditions => [
                { class => 'Public::Orders', method => 'standard_shipment_address_matches_invoice_address', operator => 'boolean', value => 'false' },
                { class => 'Public::Orders', method => 'shipping_address_used_before_for_customer', operator => 'boolean', value => 'false' },
            ],
        },
        { flag => $FLAG__DELIVERY_SIGNATURE_OPT_OUT, conditions => [
                { class => 'Public::Orders', method => 'is_signature_not_required_for_standard_class_shipment' },
            ],
        },

        # Hot List Flags
        { flag => $FLAG__FRAUD_CREDIT_CARD, conditions => [
                { class => 'Public::Orders', method => 'is_in_hotlist', params => '[ "Card Number" ]' },
            ],
        },
        { flag => $FLAG__FRAUD_ADDRESS, conditions => [
                { class => 'Public::Orders', method => 'is_in_hotlist', params => '[ "Street Address", "Town/City", "County/State" ]' },
            ],
        },
        { flag => $FLAG__FRAUD_POSTCODE, conditions => [
                { class => 'Public::Orders', method => 'is_in_hotlist', params => '[ "Postcode/Zipcode" ]' },
            ],
        },
        { flag => $FLAG__FRAUD_COUNTRY, conditions => [
                { class => 'Public::Orders', method => 'is_in_hotlist', params => '[ "Country" ]' },
            ],
        },
        { flag => $FLAG__FRAUD_EMAIL, conditions => [
                { class => 'Public::Orders', method => 'is_in_hotlist', params => '[ "Email" ]' },
            ],
        },
        { flag => $FLAG__FRAUD_TELEPHONE, conditions => [
                { class => 'Public::Orders', method => 'is_in_hotlist', params => '[ "Telephone" ]' },
            ],
        },

        { flag => $FLAG__MULTI_CHANNEL_CUSTOMER, conditions => [
                { class => 'Public::Customer', method => 'is_on_other_channels' },
            ],
        },
        { flag => $FLAG__FINANCE_WATCH, conditions => [
                { class => 'Public::Customer', method => 'has_finance_watch_flag' },
            ],
        },

        # Payment Card Flags
        { flag => $FLAG__NEW_CARD, conditions => [
                { class => 'Public::Orders', method => 'has_psp_reference' },
                { class => 'Public::Orders', method => 'is_paid_using_credit_card' },
                { class => 'Public::Orders', method => 'is_payment_card_new' },
            ],
        },
        { flag => $FLAG__DATA_NOT_CHECKED, conditions => [
                { class => 'Public::Orders', method => 'has_psp_reference' },
                { class => 'Public::Orders', method => 'payment_card_avs_response', operator => 'eq', value => 'DATA NOT CHECKED' },
            ],
        },
        { flag => $FLAG__DATA_NOT_CHECKED, conditions => [
                { class => 'Public::Orders', method => 'has_psp_reference' },
                { class => 'Public::Orders', method => 'payment_card_avs_response', operator => 'eq', value => 'NONE' },
            ],
        },
        { flag => $FLAG__SECURITY_CODE_MATCH, conditions => [
                { class => 'Public::Orders', method => 'has_psp_reference' },
                { class => 'Public::Orders', method => 'payment_card_avs_response', operator => 'eq', value => 'SECURITY CODE MATCH ONLY' },
            ],
        },
        { flag => $FLAG__ALL_MATCH, conditions => [
                { class => 'Public::Orders', method => 'has_psp_reference' },
                { class => 'Public::Orders', method => 'payment_card_avs_response', operator => 'eq', value => 'ALL MATCH' },
            ],
        },

        { flag => $FLAG__1ST, conditions => [
                { class => 'Public::Orders', method => 'is_customers_nth_order', params => '[ 1 ]' },
            ],
        },
        { flag => $FLAG__2ND, conditions => [
                { class => 'Public::Customer', method => 'is_credit_checked', operator => 'boolean', value => 'false' },
                { class => 'Public::Orders', method => 'is_customers_nth_order', params => '[ 2 ]' },
            ],
        },
        { flag => $FLAG__3RD, conditions => [
                { class => 'Public::Customer', method => 'is_credit_checked', operator => 'boolean', value => 'false' },
                { class => 'Public::Orders', method => 'is_customers_nth_order', params => '[ 3 ]' },
            ],
        },
        { flag => $FLAG__NO_CREDIT_CHECK, conditions => [
                { class => 'Public::Customer', method => 'is_credit_checked', operator => 'boolean', value => 'false' },
                { class => 'Public::Orders',   method => 'order_sequence_for_customer', params => '[ { "on_all_channels":1 } ]', operator => '>=', value => '4' },
                { class => 'Public::Customer', method => 'has_orders_older_than_not_cancelled', params => '[ { "count":6, "period":"month" } ]', operator => 'boolean', value => 'false' },
            ],
        },
        { flag => $FLAG__EXISTING_CCHECK, conditions => [
                { class => 'Public::Customer', method => 'has_order_on_credit_check_on_any_channel' },
            ]
        },
        { flag => $FLAG__EXISTING_CHOLD, conditions => [
                { class => 'Public::Customer', method => 'has_orders_on_credit_hold_on_any_channel' },
            ],
        },
        { flag => $FLAG__HIGH_VALUE, conditions => [
                { class => 'Public::Orders', method => 'get_total_value_in_local_currency', params => '[ { "want_original_purchase_value":1 } ]', operator => '>', value => 'P[LUT.Public::CreditHoldThreshold.value,name=Single Order Value:channel]' },
            ],
        },
        { flag => $FLAG__TOTAL_ORDER_VALUE_LIMIT, conditions => [
                { class => 'Public::Customer', method => 'total_spend_in_last_n_period_on_all_channels', params => '[ { "count":6, "period":"month", "want_original_purchase_value":1 } ]', operator => '>=', value => 'P[LUT.Public::CreditHoldThreshold.value,name=Total Order Value:channel]' },
                { class => 'Public::Customer', method => 'total_spend_in_last_n_period_on_all_channels', params => '[ { "count":6, "period":"month", "want_original_purchase_value":1 } ]', operator => '<', value => 'P[LUT.Public::CreditHoldThreshold.value,name=Total Order Value:channel] + P[SMC.Public::Orders.get_original_total_value_in_local_currency:nocache]', eval_value => 1 },
            ],
        },
        { flag => $FLAG__WEEKLY_ORDER_VALUE_LIMIT, conditions => [
                { class => 'Public::Customer', method => 'total_spend_in_last_n_period_on_all_channels', params => '[ { "count":7, "period":"day", "want_original_purchase_value":1 } ]', operator => '>', value => 'P[LUT.Public::CreditHoldThreshold.value,name=Weekly Order Value:channel]' },
            ],
        },
        { flag => $FLAG__WEEKLY_ORDER_COUNT_LIMIT, conditions => [
                { class => 'Public::Customer', method => 'number_of_orders_in_last_n_periods', params => '[ { "count":7, "period":"day", "on_all_channels":1 } ]', operator => '>=', value => 'P[LUT.Public::CreditHoldThreshold.value,name=Weekly Order Count:channel]' },
            ],
        },
        { flag => $FLAG__DAILY_ORDER_COUNT_LIMIT, conditions => [
                { class => 'Public::Customer', method => 'number_of_orders_in_last_n_periods', params => '[ { "count":24, "period":"hour", "on_all_channels":1 } ]', operator => '>=', value => 'P[LUT.Public::CreditHoldThreshold.value,name=Daily Order Count:channel]' },
            ],
        },

        # PayPal Flag
        { flag => $FLAG__PAID_USING_PAYPAL, add_once => 1, conditions => [
                { class => 'Public::Orders', method => 'is_paid_using_third_party_psp' },
                { class => 'Public::Orders', method => 'is_paid_using_the_third_party_psp', params => '["PayPal"]' },
            ],
        },

        # Klarna Flag
        { flag => $FLAG__PAID_USING_KLARNA, add_once => 1, conditions => [
                { class => 'Public::Orders', method => 'is_paid_using_third_party_psp' },
                { class => 'Public::Orders', method => 'is_paid_using_the_third_party_psp', params => '["Klarna"]' },
            ],
        },
    );

    return \@flags;
}

sub _build_outcome {
    my $self    = shift;
    return XT::FraudRules::Engine::Outcome->new( {
        schema          => $self->schema,
        rule_set_used   => $self->rule_set,
        logger          => $self->logger,
    } );
}

# used to build a 'XT::Rules::Condition'
# object so that it can be compiled & evaluated
sub _build_condition_obj {
    my ( $self, $condition_to_evaluate )    = @_;

    return XT::Rules::Condition->new( {
        to_evaluate => $condition_to_evaluate,
        channel     => $self->channel,
        cache       => $self->_cache,
        objects => [
            $self->order,
            $self->customer,
        ],
        die_on_error => 1,
        logger => $self->logger,
    } );
}

# decide whether the Rule Metric Counters should
# be incremented or not when processing the Rules
sub _update_rule_metrics {
    my $self    = shift;

    # as of CANDO-8384 Live Rules don't get
    # updated here but via a Job Queue request
    return 0    if ( $self->using_live_rule_set );
    return 0    if ( $self->in_parallel_mode );

    return 1;
}

