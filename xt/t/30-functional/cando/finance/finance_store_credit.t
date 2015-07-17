#!/usr/bin/env perl

use NAP::policy qw( class test );

BEGIN {
    extends "NAP::Test::Class";
}

use Test::XT::Flow;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw( :authorisation_level );
use XTracker::Config::Local qw( config_var );

=head1 NAME

finance_store_credit.t

=head1 DESCRIPTION

 Verifies the Finance > Store Credit page has correct validation

=head1 TESTS

=head2 startup

Initialise framework

=cut

sub startup : Test( startup => no_plan ) {
    my $self = shift;

    $self->SUPER::startup;

    $self->{framework} = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Finance',
        ],
    );

    $self->{framework}->login_with_permissions({
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                "Finance/Store Credits",
            ],
        },
        dept => "Finance",
    });


}

=head2 setup

Runs before each test

=cut

sub setup : Tests(setup => no_plan ) {
    my $self = shift;

    my $channel = Test::XTracker::Data->get_local_channel;
    my $id = Test::XTracker::Data->create_test_customer(
        channel_id => $channel->id
    );
    $self->{channel_id } = $channel->id;
    $self->{customer} = Test::XTracker::Data->get_schema
                                            ->resultset('Public::Customer')
                                            ->find($id);
    $self->{currency_code}  = config_var('Currency','local_currency_code');

}

=head2 test__store_Credit_page

Tests creation of Store Credit Page. Checks valid response is shown to user.

=cut

sub test__store_Credit_page : Tests() {
    my $self = shift;

    my $flow = $self->{framework};

    note 'Testing Store Credit Page';

    my %tests = (
        "Numeric value, Valid" => {
            setup => {
                value => '100',
            },
            # Since we do not actually hit StoreCredit API in the test
            # this is the error we get
            expect => "Error response from website",
        },
        "Value with comma, Valid" => {
            setup => {
                value => '100,00',
            },
            expect => "Error response from website",
        },
        "Value with spaces and commas" => {
            setup => {
                value => ' 300, 00 , 00',
            },
            expect => "Error response from website",
        },
        "Value with dot, Valid " => {
            setup => {
                value => '302.30',
            },
            expect => "Error response from website",
        },
        "Alphanumeric Value , Invalid " => {
            setup => {
                value => 'Ab12',
            },
            expect => "Value is not Numeric. Please input Numeric value",
        },


    );

    foreach my $label ( keys %tests ) {
        note "Testing: ${label}";
        my $test   = $tests{ $label };
        my $setup  = $test->{setup};
        my $expect = $test->{expect};

        $flow->flow_mech__finance__store_credit;
        $flow->flow_mech__finance__create_store_credit;

        $flow->catch_error(
            qr {$expect},
            'Got Error',
            flow_mech__finance__create_store_credit_submit => {
            channel => $self->{channel_id},
            customer_nr => $self->{customer}->is_customer_number,
            value => $setup->{value},
            currency => $self->{currency_code},
            notes => 'XYZ'
        });

    }

}

sub test_deny_store_credit : Tests() {
    my $self = shift;

    my $flow = $self->{framework};

    my $deeply_original = $flow->mech->client_parse_cell_deeply();
    $flow->mech->client_parse_cell_deeply(1);

    $flow->flow_mech__finance__store_credit
        ->flow_mech__finance__create_store_credit;

    my $data = $flow->mech->as_data;

    my $jc_channel_id = $self->schema->resultset('Public::Channel')->jimmy_choo->id;

    foreach my $channel ( @{$data->{page_data}->{'Sales Channel'}->{select_values}} ) {
        my ($channel_id, $name, $deny_store_credit) = @{ $channel };

        # No store credit for Jimmy Choo
        my $expected_deny_store_credit = ($channel_id == $jc_channel_id) ? 1 : 0;

        is(
            $deny_store_credit,
            $expected_deny_store_credit,
            "Correct Store Credit for $name"
        );
    }

    $flow->mech->client_parse_cell_deeply($deeply_original);
}

Test::Class->runtests;
