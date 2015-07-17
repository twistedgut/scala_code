package Test::XTracker::Schema::Role::Result::FraudRule;
use NAP::policy "tt", 'test';
use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Schema::Role::Result::FraudRule

=head1 SYNOPSIS

Will test Both 'Result' and 'ResulSet' Roles.

=head1 TESTS

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::FraudRule;
use Test::XT::Data;
use Test::XTracker::Mock::PSP;

use XTracker::Constants::FromDB         qw( :order_status :customer_category );

use XT::FraudRules::Engine::Outcome;

use List::Util                          qw( shuffle );


# to be done first before ALL the tests start
sub startup : Test( startup => 0 ) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema}     = Test::XTracker::Data->get_schema;
    $self->{dbh}        = $self->{schema}->storage->dbh;
    $self->{channels}   = [ Test::XTracker::Data->get_enabled_channels->all ];

    Test::XTracker::Mock::PSP->use_all_mocked_methods();    # get the PSP Mock in a known state
}

# to be done BEFORE each test runs
sub setup : Test( setup => 0 ) {
    my $self = shift;
    $self->SUPER::setup;

    # provide a list of Test Conditions
    $self->{test_conditions} = Test::XTracker::Data::FraudRule->test_conditions;

    $self->schema->txn_begin;
}

# to be done AFTER every test runs
sub teardown : Test( teardown => 0 ) {
    my $self = shift;
    $self->SUPER::teardown;

    $self->schema->txn_rollback;
}

# to be done after ALL tests have run
sub test_shutdown : Test( shutdown => no_plan ) {
    my $self = shift;
    $self->SUPER::shutdown;

    Test::XTracker::Mock::PSP->use_all_original_methods();
}


=head2 test_get_active_rules_for_channel

Tests that the correct Rules are Passed back when calling the
resultset method 'get_active_rules_to_apply' on those Classes
that use the Role.

=cut

sub test_get_active_rules_for_channel : Tests() {
    my $self    = shift;

    my @channels    = @{ $self->{channels} };

    # remove existing Live & Staging Rules and Conditions
    $self->schema->resultset( $_ )->delete      foreach ( qw(
        Fraud::LiveCondition
        Fraud::StagingCondition
        Fraud::StagingRule
        Fraud::LiveRule
    ) );

    # setup some dates for the rules
    my $now = DateTime->now( time_zone => 'local' );
    my %dates       = (
        # by calling the method 'get_active_rules_for_channel' without passing any
        # paramaters implies use 'now' as the date but because time moves on whilst
        # the test script is running 'now' won't be the same as it is at this point
        # so delibratey take 30 seconds off 'now' here so that a later test doesn't
        # accidentally pick up 'now' records should the script run so quickly it's
        # still the same second
        now             => $now->clone->subtract( seconds => 30 ),
        yesterday       => $now->clone->subtract( days => 1 ),
        tomorrow        => $now->clone->add( days => 1 ),
        the_past        => $now->clone->subtract( months => 3 ),
        the_future      => $now->clone->add( months => 4 ),
    );

    note "Dates Used in Tests:";
    note "    ${_} - " . $dates{ $_ }       foreach ( keys %dates );

    # define some Rules which have a mixture of Start/End Dates
    my @rule_definitions    = (
        { rule_name => 'NO DATES 1',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD },
        { rule_name => 'START DATE NOW',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_start_date  => $dates{now} },
        { rule_name => 'START DATE THE PAST',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_start_date  => $dates{the_past} },
        { rule_name => 'START DATE YESTERDAY',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD, rule_start_date  => $dates{yesterday} },
        { rule_name => 'START DATE TOMORROW',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_start_date  => $dates{tomorrow} },
        { rule_name => 'START DATE THE FUTURE',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD, rule_start_date  => $dates{the_future} },
        { rule_name => 'NO DATES 2',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD },
        { rule_name => 'NO DATES 3',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD },
        { rule_name => 'END DATE THE PAST',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_end_date    => $dates{the_past} },
        { rule_name => 'END DATE YESTERDAY',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD, rule_end_date    => $dates{yesterday} },
        { rule_name => 'END DATE TOMORROW',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_end_date    => $dates{tomorrow} },
        { rule_name => 'END DATE THE FUTURE',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD, rule_end_date    => $dates{the_future} },
        { rule_name => 'END DATE NOW',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD, rule_end_date    => $dates{now} },
        { rule_name => 'NO DATES 4',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED },
        { rule_name => 'NO DATES 5',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED },
        { rule_name => 'START DATE NOW, END DATE TOMORROW',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_start_date  => $dates{now},         rule_end_date => $dates{tomorrow} },
        { rule_name => 'START DATE YESTERDAY, END DATE NOW',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD, rule_start_date  => $dates{yesterday},   rule_end_date => $dates{now} },
        { rule_name => 'START DATE THE PAST, END DATE YESTERDAY',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_start_date  => $dates{the_past},    rule_end_date => $dates{yesterday} },
        { rule_name => 'START DATE YESTERDAY, END DATE TOMORROW',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD, rule_start_date  => $dates{yesterday},   rule_end_date => $dates{tomorrow} },
        { rule_name => 'START DATE TOMORROW, END DATE THE FUTURE',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_start_date  => $dates{tomorrow},    rule_end_date => $dates{the_future} },
        { rule_name => 'START DATE THE PAST, END DATE THE FUTURE',
                    rule_action_status_id => $ORDER_STATUS__ACCEPTED,    rule_start_date  => $dates{the_past},    rule_end_date => $dates{the_future} },
        { rule_name => 'NO DATES 6',
                    rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD },
    );
    # clone the above Rules but have them all Disabled
    push @rule_definitions, map { { %{ $_ }, rule_name => $_->{rule_name} . ' disabled', rule_enabled => 0 } } @rule_definitions;

    # get a list of sequences and then randomly assing to each Rule, the '* 2' is to add on the All Sales Channel Rules
    my @sequences   = shuffle( 1..( ( scalar( @rule_definitions ) * 2 ) *  scalar( @channels ) ) );
    # assign the above Rules to All Channels, 'undef' will mean All Sales Channels
    my @channel_definitions;
    foreach my $channel ( ( @channels, undef ) ) {
        push @channel_definitions, map { {
            %{ $_ },
            rule_name => ( defined $channel ? $_->{rule_name} : 'ALL CHANNELS - ' . $_->{rule_name} ),
            channel => $channel,
            number_of_conditions => 1,      # no need to create more than one Condition
            rule_sequence => shift @sequences,
        } } @rule_definitions;
    }

    my @rules   = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', \@channel_definitions );
    my %rules_by_channel;
    foreach my $rule ( sort { $a->rule_sequence <=> $b->rule_sequence } @rules ) {
        push @{ $rules_by_channel{ $rule->channel_id } }, $rule;
    }

    # list all of the 'NO DATES' Rules which
    # should always be in any List of Rules
    my @no_dates    = (
        'NO DATES 1',
        'NO DATES 2',
        'NO DATES 3',
        'NO DATES 4',
        'NO DATES 5',
        'NO DATES 6',
    );

    my %tests   = (
        "Get All Rules for NOW by passing in NO Params" => {
            # remember 'now' was adjusted to be 30 seconds in the past
            # near the top of this test method, because time would have
            # moved on by the time this test gets run so none of the
            # 'END NOW' Rules will be picked up
            expected    => [
                @no_dates,
                'START DATE NOW',
                'START DATE THE PAST',
                'START DATE YESTERDAY',
                'END DATE TOMORROW',
                'END DATE THE FUTURE',
                'START DATE NOW, END DATE TOMORROW',
                'START DATE YESTERDAY, END DATE TOMORROW',
                'START DATE THE PAST, END DATE THE FUTURE',
            ],
        },
        "Get All Rules for NOW by passing explicitly 'NOW' as a Paramater" => {
            date        => $dates{now},
            expected    => [
                @no_dates,
                'START DATE NOW',
                'START DATE THE PAST',
                'START DATE YESTERDAY',
                'END DATE TOMORROW',
                'END DATE THE FUTURE',
                'END DATE NOW',
                'START DATE NOW, END DATE TOMORROW',
                'START DATE YESTERDAY, END DATE NOW',
                'START DATE YESTERDAY, END DATE TOMORROW',
                'START DATE THE PAST, END DATE THE FUTURE',
            ],
        },
        "Get Rules using 'Tomorrow'" => {
            date        => $dates{tomorrow},
            expected    => [
                @no_dates,
                'START DATE NOW',
                'START DATE THE PAST',
                'START DATE YESTERDAY',
                'START DATE TOMORROW',
                'END DATE TOMORROW',
                'END DATE THE FUTURE',
                'START DATE NOW, END DATE TOMORROW',
                'START DATE YESTERDAY, END DATE TOMORROW',
                'START DATE TOMORROW, END DATE THE FUTURE',
                'START DATE THE PAST, END DATE THE FUTURE',
            ],
        },
        "Get Rules using 'Yesterday'" => {
            date        => $dates{yesterday},
            expected    => [
                @no_dates,
                'START DATE THE PAST',
                'START DATE YESTERDAY',
                'END DATE YESTERDAY',
                'END DATE TOMORROW',
                'END DATE THE FUTURE',
                'END DATE NOW',
                'START DATE YESTERDAY, END DATE NOW',
                'START DATE THE PAST, END DATE YESTERDAY',
                'START DATE YESTERDAY, END DATE TOMORROW',
                'START DATE THE PAST, END DATE THE FUTURE',
            ],
        },
        "Get Rules using a Date sometime before 'The Future'" => {
            date        => $dates{the_future}->clone->subtract( weeks => 3 ),
            expected    => [
                @no_dates,
                'START DATE NOW',
                'START DATE THE PAST',
                'START DATE YESTERDAY',
                'START DATE TOMORROW',
                'END DATE THE FUTURE',
                'START DATE TOMORROW, END DATE THE FUTURE',
                'START DATE THE PAST, END DATE THE FUTURE',
            ],
        },
        "Get Rules using a Date sometime after 'The Past'" => {
            date        => $dates{the_past}->clone->add( weeks => 3 ),
            expected    => [
                @no_dates,
                'START DATE THE PAST',
                'END DATE YESTERDAY',
                'END DATE TOMORROW',
                'END DATE THE FUTURE',
                'END DATE NOW',
                'START DATE THE PAST, END DATE YESTERDAY',
                'START DATE THE PAST, END DATE THE FUTURE',
            ],
        },
        "Get Rules using a Date a long time in 'The Future'" => {
            date        => $dates{the_future}->clone->add( years => 101 ),
            expected    => [
                @no_dates,
                'START DATE NOW',
                'START DATE THE PAST',
                'START DATE YESTERDAY',
                'START DATE TOMORROW',
                'START DATE THE FUTURE',
            ],
        },
        "Get Rules using a Date a long time in 'The Past'" => {
            date        => $dates{the_past}->clone->subtract( years => 101 ),
            expected    => [
                @no_dates,
                'END DATE THE PAST',
                'END DATE YESTERDAY',
                'END DATE TOMORROW',
                'END DATE THE FUTURE',
                'END DATE NOW',
            ],
        },
    );

    my $live_rule_rs    = $self->schema->resultset('Fraud::LiveRule');
    my $staging_rule_rs = $self->schema->resultset('Fraud::StagingRule');

    foreach my $label ( keys %tests ) {
        note "Testing: '${label}'";
        my $test    = $tests{ $label };
        my @expected= @{ $test->{expected} };
        # add in the 'ALL CHANNELS' version of each Expected Rule
        push @expected, map { "ALL CHANNELS - ${_}" } @expected;

        foreach my $channel ( @channels ) {
            note "for Sales Channel: " . $channel->name;

            # get Live Rules
            my @rules       = $live_rule_rs->get_active_rules_for_channel( $channel, $test->{date} )->all;
            my @rule_names  = sort map { $_->name } @rules;
            is_deeply( \@rule_names, [ sort @expected ], "Live Rules, got Expected Rules" );
            is_deeply(
                [ map { $_->rule_sequence } @rules ],
                [ sort { $a <=> $b } map { $_->rule_sequence } @rules ],
                "and are sorted in Rule Sequence order"
            );
            is_deeply(
                { map { ( $_->channel_id ? $_->channel_id : 0 ) => 1 } @rules },
                # '0' denotes All Channels
                { 0 => 1, $channel->id => 1 },
                "and are for Only the requested Sales Channel"
            );

            # get Staging Rules
            @rules      = $staging_rule_rs->get_active_rules_for_channel( $channel, $test->{date} )->all;
            @rule_names = sort map { $_->name } @rules;
            is_deeply( \@rule_names, [ sort @expected ], "Staging Rules, got Expected Rules" );
            is_deeply(
                [ map { $_->rule_sequence } @rules ],
                [ sort { $a <=> $b } map { $_->rule_sequence } @rules ],
                "and are sorted in Rule Sequence order"
            );
            is_deeply(
                { map { ( $_->channel_id ? $_->channel_id : 0 ) => 1 } @rules },
                # '0' denotes All Channels
                { 0 => 1, $channel->id => 1 },
                "and are for Only the requested Sales Channel"
            );
        }
    }
}

=head2 test_textualise

Tests the Result Method 'textualise' for the Rules.

=cut

sub test_textualise : Tests() {
    my $self    = shift;

    my $expected    = "This is a Test Description for a Rule";

    my ( $live_rule )   = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
        rule_name   => $expected,
    } );
    my $staging_rule    = $live_rule->staging_rules->first;
    my $archived_rule   = $live_rule->archived_rule;

    is( $live_rule->textualise, $expected, "For 'Live' Rule: Text as Expected: '${expected}'" );
    is( $staging_rule->textualise, $expected, "For 'Staging' Rule: Text as Expected: '${expected}'" );
    is( $archived_rule->textualise, $expected, "For 'Archived' Rule: Text as Expected: '${expected}'" );
}

=head2 test_conditions_relationship

This tests the 'conditions' Result method that gets the Conditions for any of the Rule Classes.

=cut

sub test_conditions_relationship : Tests() {
    my $self    = shift;

    my ( $live_rule )   = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', {
        number_of_conditions => 5,
    } );
    my $staging_rule    = $live_rule->staging_rules->first;
    my $archived_rule   = $live_rule->archived_rule;

    my %tests = (
        Live    => {
            rule        => $live_rule,
            conditions  => [
                $live_rule->live_conditions->search( {}, { order_by => 'id' } )->all
            ],
        },
        Staging => {
            rule        => $staging_rule,
            conditions  => [
                $staging_rule->staging_conditions->search( {}, { order_by => 'id' } )->all
            ],
        },
        Archived => {
            rule        => $archived_rule,
            conditions  => [
                $archived_rule->archived_conditions->search( {}, { order_by => 'id' } )->all
            ],
        },
    );

    foreach my $label ( keys %tests ) {
        note "Testing: '${label}' Rule";
        my $test    = $tests{ $label };

        my $rs  = $test->{rule}->conditions;
        isa_ok( $rs, "XTracker::Schema::ResultSet::Fraud::${label}Condition", "'conditions' returned a ResultSet" );
        my @conditions  = $rs->search( {}, { order_by => 'id' } )->all;
        is_deeply(
            [ map { $_->id } @conditions ],
            [ map { $_->id } @{ $test->{conditions} } ],
            "using 'all' on the ResultSet got the expected Condition Ids"
        );
    }
}

=head2 test_process_rule

Tests the 'process_rule' Result method that processes all Conditions for a Rule.

=cut

sub test_process_rule : Tests() {
    my $self    = shift;

    my %test_conditions = %{ $self->{test_conditions} };

    my %tests   = (
        "The First Condition Fails" => {
            update_metrics      => 1,
            conditions_to_use   => [
                $test_conditions{"Is Customer's Third Order - TRUE"},
                $test_conditions{"Is Customer's First Order - TRUE"},
                $test_conditions{"Customer is an EIP - FALSE"},
            ],
            expect  => {
                rule_passed => 0,
                outcome => [
                    { textualisation => "Is Customer's Third Order", passed => 0 },
                ],
            },
        },
        "The Second Condition Fails" => {
            conditions_to_use   => [
                $test_conditions{"Is Customer's First Order - TRUE"},
                $test_conditions{"Is Customer's Third Order - TRUE"},
                $test_conditions{"Customer is an EIP - FALSE"},
            ],
            expect  => {
                rule_passed => 0,
                outcome => [
                    { textualisation => "Is Customer's First Order", passed => 1 },
                    { textualisation => "Is Customer's Third Order", passed => 0 },
                ],
            },
        },
        "The Third Condition Fails" => {
            conditions_to_use   => [
                $test_conditions{"Is Customer's First Order - TRUE"},
                $test_conditions{"Customer is an EIP - FALSE"},
                $test_conditions{"Is Customer's Third Order - TRUE"},
                $test_conditions{"Number of Orders in last 7 days - <= 3"},
            ],
            expect  => {
                rule_passed => 0,
                outcome => [
                    { textualisation => "Is Customer's First Order", passed => 1 },
                    { textualisation => "Customer is an EIP", passed => 1 },
                    { textualisation => "Is Customer's Third Order", passed => 0 },
                ],
            },
        },
        "The Final Condition Fails" => {
            conditions_to_use   => [
                $test_conditions{"Is Customer's First Order - TRUE"},
                $test_conditions{"Customer is an EIP - FALSE"},
                $test_conditions{"Number of Orders in last 7 days - <= 3"},
                $test_conditions{"Is Customer's Third Order - TRUE"},
            ],
            expect  => {
                rule_passed => 0,
                outcome => [
                    { textualisation => "Is Customer's First Order", passed => 1 },
                    { textualisation => "Customer is an EIP", passed => 1 },
                    { textualisation => "Number of Orders in last 7 days", passed => 1 },
                    { textualisation => "Is Customer's Third Order", passed => 0 },
                ],
            },
        },
        "Only One Condition and it Fails" => {
            update_metrics      => 1,
            conditions_to_use   => [
                $test_conditions{"Is Customer's First Order - FALSE"},
            ],
            expect  => {
                rule_passed => 0,
                outcome => [
                    { textualisation => "Is Customer's First Order", passed => 0 },
                ],
            },
        },
        "Only One Condition and it Passes" => {
            update_metrics      => 1,
            conditions_to_use   => [
                $test_conditions{"Is Customer's First Order - TRUE"},
            ],
            expect  => {
                rule_passed => 1,
                outcome => [
                    { textualisation => "Is Customer's First Order", passed => 1 },
                ],
            },
        },
        "Five Conditions and they All Pass" => {
            update_metrics      => 1,
            conditions_to_use   => [
                $test_conditions{"Is Customer's First Order - TRUE"},
                $test_conditions{"Customer is an EIP - FALSE"},
                $test_conditions{"Number of Orders in last 7 days - <= 3"},
                $test_conditions{"Shipping Address Equal To Billing Address - FALSE"},
                $test_conditions{"Shipping Address Country - Is Not Brazil"},
            ],
            expect  => {
                rule_passed => 1,
                outcome => [
                    { textualisation => "Is Customer's First Order", passed => 1 },
                    { textualisation => "Customer is an EIP", passed => 1 },
                    { textualisation => "Number of Orders in last 7 days", passed => 1 },
                    { textualisation => "Shipping Address Equal To Billing Address", passed => 1 },
                    { textualisation => "Shipping Address Country", passed => 1 },
                ],
            },
        },
        "An 'Accept' Action Rule Passes" => {
            rule_action_status_id   => $ORDER_STATUS__ACCEPTED,
            conditions_to_use   => [
                $test_conditions{"Is Customer's First Order - TRUE"},
                $test_conditions{"Number of Orders in last 7 days - <= 3"},
                $test_conditions{"Shipping Address Country - Is Not Brazil"},
            ],
            expect  => {
                rule_passed => 1,
                outcome => [
                    { textualisation => "Is Customer's First Order", passed => 1 },
                    { textualisation => "Number of Orders in last 7 days", passed => 1 },
                    { textualisation => "Shipping Address Country", passed => 1 },
                ],
            },
        },
        "A 'Credit Hold' Action Rule Passes" => {
            update_metrics      => 1,
            rule_action_status_id   => $ORDER_STATUS__CREDIT_HOLD,
            conditions_to_use   => [
                $test_conditions{"Customer is an EIP - FALSE"},
                $test_conditions{"Number of Orders in last 7 days - <= 3"},
                $test_conditions{"Shipping Address Equal To Billing Address - FALSE"},
            ],
            expect  => {
                rule_passed => 1,
                outcome => [
                    { textualisation => "Customer is an EIP", passed => 1 },
                    { textualisation => "Number of Orders in last 7 days", passed => 1 },
                    { textualisation => "Shipping Address Equal To Billing Address", passed => 1 },
                ],
            },
        },
        "When Using a Disabled Condition it doesn't get used" => {
            update_metrics      => 1,
            rule_action_status_id   => $ORDER_STATUS__CREDIT_HOLD,
            conditions_to_use   => [
                $test_conditions{"Disabled - Customer is an EIP - TRUE"},
                $test_conditions{"Customer is an EIP - FALSE"},
                $test_conditions{"Number of Orders in last 7 days - <= 3"},
                $test_conditions{"Shipping Address Equal To Billing Address - FALSE"},
            ],
            expect  => {
                rule_passed => 1,
                outcome => [
                    { textualisation => "Customer is an EIP", passed => 1 },
                    { textualisation => "Number of Orders in last 7 days", passed => 1 },
                    { textualisation => "Shipping Address Equal To Billing Address", passed => 1 },
                ],
            },
        },
    );

    my $cache   = {};
    my $order   = Test::XTracker::Data::FraudRule->create_order();
    my $channel = $order->channel;
    my @objects = ( $order, $order->customer );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";

        my $test            = $tests{ $label };
        my $expect          = delete $test->{expect};
        my $update_metrics  = delete $test->{update_metrics} // 0;

        $test->{channel}    = $channel;
        $expect->{update_metrics} = $update_metrics;

        my $live_rule   = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live', $test );
        my %rules   = (
            live    => $live_rule,
            staging => $live_rule->staging_rules->first,
        );

        while ( my ( $rule_set, $rule ) = each %rules ) {
            # create an Outcome object to store what gets processed
            my $outcome = XT::FraudRules::Engine::Outcome->new( {
                schema          => $self->schema,
                rule_set_used   => 'live',
            } );

            my $result  = $rule->process_rule( {
                cache           => $cache,
                object_list     => \@objects,
                outcome         => $outcome,
                update_metrics  => $update_metrics,
            } );
            $self->_check_processed_rule( $rule, $outcome, $expect );
        }
    }
}

=head2 test_increment_metric

Tests the Result Method 'increment_metric' which increments the metric counters by 1.

=cut

sub test_increment_metric : Tests() {
    my $self    = shift;

    my ( $live_rule )   = Test::XTracker::Data::FraudRule->create_fraud_rule( 'Live' );
    my $staging_rule    = $live_rule->staging_rules->first;
    my $archvied_rule   = $live_rule->archived_rule;

    # contains the different Classes of the Rule
    my %rule_class  = (
        Live    => $live_rule,
        Staging => $live_rule->staging_rules->first,
        Archived=> $live_rule->archived_rule,
    );

    foreach my $rule_set ( 'Live', 'Staging' ) {
        note "Testing: '${rule_set}' Rule";
        my $rule    = $rule_class{ $rule_set };

        # just call the method the 5 Times
        $rule->discard_changes->increment_metric            foreach ( 1..5 );
        cmp_ok( $rule->discard_changes->metric_used, '==', 5, "'metric_used' counter is now at 5" );
        cmp_ok( $rule->metric_decided, '==', 0, "'metric_decided' counter still at 0" );

        # now call it again 5 times but this time pass a
        # flag to increment the 'metric_decided' counter
        $rule->discard_changes->increment_metric( 1 )       foreach ( 1..5 );
        cmp_ok( $rule->discard_changes->metric_used, '==', 10, "With 'Decided' Flag, 'metric_used' counter is now at 10" );
        cmp_ok( $rule->metric_decided, '==', 5, "With 'Decided' Flag, 'metric_decided' counter still at 5" );
    }

    note "Testing: 'Archived' Rule, should't increment Metrics";
    # just call the method the 5 Times
    $rule_class{Archived}->discard_changes->increment_metric             foreach ( 1..5 );
    cmp_ok( $rule_class{Archived}->discard_changes->metric_used, '==', 0, "'metric_used' counter is still at 0" );
    cmp_ok( $rule_class{Archived}->metric_decided, '==', 0, "'metric_decided' counter still at 0" );

    # now call it again 5 times but this time pass a
    # flag to increment the 'metric_decided' counter
    $rule_class{Archived}->discard_changes->increment_metric( 1 )        foreach ( 1..5 );
    cmp_ok( $rule_class{Archived}->discard_changes->metric_used, '==', 0, "With 'Decided' Flag, 'metric_used' counter is now at 0" );
    cmp_ok( $rule_class{Archived}->metric_decided, '==', 0, "With 'Decided' Flag, 'metric_decided' counter still at 0" );
}

=head2 test_process_rules_for_channel

Tests the ResultSet method 'process_rules_for_channel' which will process all the Rules for a Sales Channel.

=cut

sub test_process_rules_for_channel : Tests() {
    my $self    = shift;

    my %test_conditions = %{ $self->{test_conditions} };

    my %tests   = (
        "The First Rule Passes" => {
            update_metrics  => 1,
            rules   => [
                { rule_name => 'Rule 1', condition => $test_conditions{"Is Customer's First Order - TRUE"} },
                { rule_name => 'Rule 2', condition => $test_conditions{"Is Customer's Second Order - FALSE"} },
                { rule_name => 'Rule 3', condition => $test_conditions{"Is Customer's Third Order - FALSE"} },
            ],
            expect  => {
                rule_passed_idx => 0,
                outcome => [
                    { textualisation => 'Rule 1', passed => 1 },
                ],
            },
        },
        "The Second Rule Passes" => {
            rules   => [
                { rule_name => 'Rule 1', condition => $test_conditions{"Is Customer's Second Order - TRUE"} },
                { rule_name => 'Rule 2', condition => $test_conditions{"Customer is an EIP - FALSE"} },
                { rule_name => 'Rule 3', condition => $test_conditions{"Is Customer's Third Order - FALSE"} },
            ],
            expect  => {
                rule_passed_idx => 1,
                outcome => [
                    { textualisation => 'Rule 1', passed => 0 },
                    { textualisation => 'Rule 2', passed => 1 },
                ],
            },
        },
        "The Third Rule Passes" => {
            update_metrics  => 1,
            rules   => [
                { rule_name => 'Rule 1', condition => $test_conditions{"Is Customer's Second Order - TRUE"} },
                { rule_name => 'Rule 2', condition => $test_conditions{"Customer is an EIP - TRUE"} },
                { rule_name => 'Rule 3', condition => $test_conditions{"Is Customer's Third Order - FALSE"} },
                { rule_name => 'Rule 4', condition => $test_conditions{"Number of Orders in last 7 days - > 3"} },
            ],
            expect  => {
                rule_passed_idx => 2,
                outcome => [
                    { textualisation => 'Rule 1', passed => 0 },
                    { textualisation => 'Rule 2', passed => 0 },
                    { textualisation => 'Rule 3', passed => 1 },
                ],
            },
        },
        "The Final Rule Passes" => {
            rules   => [
                { rule_name => 'Rule 1', condition => $test_conditions{"Is Customer's Second Order - TRUE"} },
                { rule_name => 'Rule 2', condition => $test_conditions{"Customer is an EIP - TRUE"} },
                { rule_name => 'Rule 3', condition => $test_conditions{"Is Customer's Third Order - TRUE"} },
                { rule_name => 'Rule 4', condition => $test_conditions{"Number of Orders in last 7 days - <= 3"} },
            ],
            expect  => {
                rule_passed_idx => 3,
                outcome => [
                    { textualisation => 'Rule 1', passed => 0 },
                    { textualisation => 'Rule 2', passed => 0 },
                    { textualisation => 'Rule 3', passed => 0 },
                    { textualisation => 'Rule 4', passed => 1 },
                ],
            },
        },
        "Only One Rule and it Passes" => {
            update_metrics  => 1,
            rules   => [
                { rule_name => 'Rule 1', condition => $test_conditions{"Is Customer's Second Order - FALSE"} },
            ],
            expect  => {
                rule_passed_idx => 0,
                outcome => [
                    { textualisation => 'Rule 1', passed => 1 },
                ],
            },
        },
        "Only One Rule and it Fails" => {
            update_metrics  => 1,
            rules   => [
                { rule_name => 'Rule 1', condition => $test_conditions{"Is Customer's Second Order - TRUE"} },
            ],
            expect  => {
                rule_passed_idx => undef,
                outcome => [
                    { textualisation => 'Rule 1', passed => 0 },
                ],
            },
        },
        "Five Rules and they All Fail" => {
            update_metrics  => 1,
            rules   => [
                { rule_name => 'Rule 1', condition => $test_conditions{"Is Customer's Second Order - TRUE"} },
                { rule_name => 'Rule 2', condition => $test_conditions{"Customer is an EIP - TRUE"} },
                { rule_name => 'Rule 3', condition => $test_conditions{"Is Customer's Third Order - TRUE"} },
                { rule_name => 'Rule 4', condition => $test_conditions{"Number of Orders in last 7 days - > 3"} },
                { rule_name => 'Rule 5', condition => $test_conditions{"Shipping Address Equal To Billing Address - TRUE"} },
            ],
            expect  => {
                rule_passed_idx => undef,
                outcome => [
                    { textualisation => 'Rule 1', passed => 0 },
                    { textualisation => 'Rule 2', passed => 0 },
                    { textualisation => 'Rule 3', passed => 0 },
                    { textualisation => 'Rule 4', passed => 0 },
                    { textualisation => 'Rule 5', passed => 0 },
                ],
            },
        },
        "Five Rules and they All Fail, but are Sequenced not in the Order they were Created" => {
            rules   => [
                { rule_name => 'Rule 1', rule_sequence => 5, condition => $test_conditions{"Is Customer's Second Order - TRUE"} },
                { rule_name => 'Rule 2', rule_sequence => 3, condition => $test_conditions{"Customer is an EIP - TRUE"} },
                { rule_name => 'Rule 3', rule_sequence => 2, condition => $test_conditions{"Is Customer's Third Order - TRUE"} },
                { rule_name => 'Rule 4', rule_sequence => 1, condition => $test_conditions{"Number of Orders in last 7 days - > 3"} },
                { rule_name => 'Rule 5', rule_sequence => 4, condition => $test_conditions{"Shipping Address Equal To Billing Address - TRUE"} },
            ],
            expect  => {
                rule_passed_idx => undef,
                outcome => [
                    { textualisation => 'Rule 4', passed => 0 },
                    { textualisation => 'Rule 3', passed => 0 },
                    { textualisation => 'Rule 2', passed => 0 },
                    { textualisation => 'Rule 5', passed => 0 },
                    { textualisation => 'Rule 1', passed => 0 },
                ],
            },
        },
        "An 'Accept' Action Rule Passes" => {
            update_metrics  => 1,
            rules   => [
                { rule_name => 'Rule 1', rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                    condition => $test_conditions{"Is Customer's Second Order - TRUE"} },
                { rule_name => 'Rule 2', rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                    condition => $test_conditions{"Customer is an EIP - TRUE"} },
                { rule_name => 'Rule 3', rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                    condition => $test_conditions{"Number of Orders in last 7 days - > 3"} },
                { rule_name => 'Rule 4', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                    condition => $test_conditions{"Shipping Address Equal To Billing Address - FALSE"} },
                { rule_name => 'Rule 5', rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                    condition => $test_conditions{"Is Customer's Third Order - TRUE"} },
            ],
            expect  => {
                expected_rule_action => $ORDER_STATUS__ACCEPTED,
                rule_passed_idx => 3,
                outcome => [
                    { textualisation => 'Rule 1', passed => 0 },
                    { textualisation => 'Rule 2', passed => 0 },
                    { textualisation => 'Rule 3', passed => 0 },
                    { textualisation => 'Rule 4', passed => 1 },
                ],
            },
        },
        "A 'Credit Hold' Action Rule Passes" => {
            update_metrics  => 1,
            rules   => [
                { rule_name => 'Rule 1', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                    condition => $test_conditions{"Is Customer's Second Order - TRUE"} },
                { rule_name => 'Rule 2', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                    condition => $test_conditions{"Customer is an EIP - TRUE"} },
                { rule_name => 'Rule 3', rule_action_status_id => $ORDER_STATUS__CREDIT_HOLD,
                                    condition => $test_conditions{"Shipping Address Country - Is Not Brazil"} },
                { rule_name => 'Rule 4', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                    condition => $test_conditions{"Number of Orders in last 7 days - > 3"} },
                { rule_name => 'Rule 5', rule_action_status_id => $ORDER_STATUS__ACCEPTED,
                                    condition => $test_conditions{"Is Customer's Third Order - TRUE"} },
            ],
            expect  => {
                expected_rule_action => $ORDER_STATUS__CREDIT_HOLD,
                rule_passed_idx => 2,
                outcome => [
                    { textualisation => 'Rule 1', passed => 0 },
                    { textualisation => 'Rule 2', passed => 0 },
                    { textualisation => 'Rule 3', passed => 1 },
                ],
            },
        },
    );

    my $cache   = {};
    my $order   = Test::XTracker::Data::FraudRule->create_order();
    my $channel = $order->channel;
    my @objects = ( $order, $order->customer );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";

        my $test            = $tests{ $label };
        my $expect          = delete $test->{expect};
        my $update_metrics  = delete $test->{update_metrics} // 0;

        $expect->{update_metrics} = $update_metrics;

        Test::XTracker::Data::FraudRule->delete_fraud_rules;
        my $rule_set    = Test::XTracker::Data::FraudRule->create_live_rule_set( $test->{rules}, $channel );
        delete $rule_set->{Archived};

        while ( my ( $rule_set, $rules ) = each %{ $rule_set } ) {
            # create an Outcome object to store what gets processed
            my $outcome = XT::FraudRules::Engine::Outcome->new( {
                schema          => $self->schema,
                rule_set_used   => lc( $rule_set ),
            } );

            my $result  = $self->rs("Fraud::${rule_set}Rule")->process_rules_for_channel( $channel, {
                cache           => $cache,
                object_list     => \@objects,
                outcome         => $outcome,
                update_metrics  => $update_metrics,
            } );
            $self->_check_processed_rules( $rule_set, $rules, $result, $outcome, $expect );
        }
    }
}

#----------------------------------------------------------------------------------------

# check to see if a Rule got processed correctly
sub _check_processed_rule {
    my ( $self, $rule, $outcome, $expect )  = @_;

    my ($type_of_rule) = ( ref( $rule->discard_changes )   =~ m/.*::(.*)Rule$/ );
    note "checking the Outcome of a '${type_of_rule}' Rule";

    my @text_rows   = $outcome->all_textualisation_rules;
    cmp_ok( @text_rows, '==', 1, "Got 1 Textualisation Row" );
    is( $text_rows[0]->{textualisation}, $rule->textualise, "Textualisation for Rule as Expected" );
    cmp_ok( $text_rows[0]->{passed}, '==', $expect->{rule_passed}, "Rule '" . _outcome_text( $expect->{rule_passed} ) . "' as Expected" );

    # make up what the expected outcome of the Conditions was
    my @expect_conditions   = map {
        {
            textualisation  => re( qr/^$_->{textualisation}/i ),
            passed          => $_->{passed},
            id              => ignore(),
        }
    } @{ $expect->{outcome} };
    cmp_deeply( $text_rows[0]->{conditions}, \@expect_conditions, "Outcome of Conditions as Expected" );

    # make up what the expected Metric Counters should have been
    my $expected_metrics    = {
        metric_used     => ( $expect->{update_metrics} ? 1 : 0 ),
        metric_decided  => ( $expect->{update_metrics} && $expect->{rule_passed} ? 1 : 0 ),
    };
    is_deeply(
        {
            metric_used     => $rule->metric_used,
            metric_decided  => $rule->metric_decided,
        },
        $expected_metrics,
        "Rule Metrics as Expected",
    );

    return;
}

# check to that a set of Rules got processed correctly
sub _check_processed_rules {
    my ( $self, $rule_set, $rules, $result_rule, $outcome, $expect )    = @_;

    note "checking the Outcome of '${rule_set}' Rules";

    my $rule_class  = "Fraud::${rule_set}Rule";
    $_->discard_changes     foreach ( @{ $rules } );

    if ( defined $expect->{rule_passed_idx} ) {
        isa_ok( $result_rule, "XTracker::Schema::Result::${rule_class}",
                            "'process_rules_for_channel' returned a Rule" );
        cmp_ok( $rules->[ $expect->{rule_passed_idx} ]->id, '==', $result_rule->id,
                            "and is the Rule that was Expected to Pass" );
        if ( my $action_id = $expect->{expected_rule_action} ) {
            cmp_ok( $result_rule->action_order_status_id, '==', $action_id,
                                    "and has the Expected Action Order Status" );
        }
    }
    else {
        ok( !defined $result_rule, "All Rules Failed so NO Rule Returned" );
    }

    # get the Textualisation and the expected Textualisation for the Rules
    my @text_rows   = $outcome->all_textualisation_rules;
    my @expect_rules= map {
        {
            textualisation  => re( qr/^$_->{textualisation}/i ),
            passed          => $_->{passed},
            id              => ignore(),
            conditions      => [
                {
                    textualisation  => ignore(),
                    passed          => $_->{passed},
                    id              => ignore(),
                }
            ],
        }
    } @{ $expect->{outcome} };
    cmp_deeply( \@text_rows, \@expect_rules, "Textualisation Outcome of Rules as Expected" ) or note "----> " . p( @text_rows );

    my $max_idx         = $#{ $rules };
    my $passed_idx      = $expect->{rule_passed_idx} // $max_idx;

    # check that the Metric Counters were/weren't updated
    my $expect_metrics  = $expect->{ update_metrics };
    my $expect_decider  = ( $expect_metrics && $result_rule ? 1 : 0 );

    my @expect_metrics  = map {
        {
            metric_used     => ( $expect_metrics && $_ <= $passed_idx ? 1 : 0 ),
            metric_decided  => (
                $expect_decider && $result_rule->id == $rules->[ $_ ]->id
                ? 1
                : 0
            ),
        }
    } ( 0..$max_idx );

    is_deeply(
        [ map {
            {
                metric_used     => $_->metric_used,
                metric_decided  => $_->metric_decided,
            }
        } @{ $rules } ],
        \@expect_metrics,
        "Rule Metrics as Expected"
    );

    # check the ResultSet of Rules Processed on the Outcome object
    isa_ok( $outcome->rules_processed_rs, "XTracker::Schema::ResultSet::${rule_class}",
                            "'rules_processed_rs' on the 'Outcome' object has a ResultSet" );
    my %got_rule_ids    = map { $_->id => 1 } $outcome->rules_processed_rs->all;
    my %expect_rule_ids = map { $_->id => 1 } @{ $rules }[ 0..$passed_idx ];
    is_deeply( \%got_rule_ids, \%expect_rule_ids, "and the ResultSet is for the Expected Rules" );

    return;
}

# give back 'Passed' or 'Failed' based on 1 or 0
sub _outcome_text {
    my $pass    = shift;
    return ( $pass ? 'Passed' : 'Failed' );
}

