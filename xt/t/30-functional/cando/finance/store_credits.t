#!/usr/bin/env perl

=head1 NAME

store_credits.t - tests Finance/ Store Credits Page

=head1 DESCRIPTION

Verifies that the customer credit log is correctly updated when updates
are made to the customer's store credit.

#TAGS xpath needsrefactor cando

=cut

use NAP::policy "tt",     'test';

use Test::XTracker::Data;
use Test::XT::DC::Mechanize;
use Test::XTracker::MessageQueue;
use NAP::CustomerCredit::TestUserAgent;
use base 'Test::Class';


sub startup : Test( startup => no_plan ) {
    my $test = shift;

    use_ok 'XT::DC::Controller::Finance::StoreCredits';

    $test->{schema} = Test::XTracker::Data->get_schema;
    $test->{mech}   = Test::XT::DC::Mechanize->new;
    $test->{amq}    = Test::XTracker::MessageQueue->new();
}

use XTracker::Config::Local             qw( config_var );
use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw( :authorisation_level );
use XTracker::Database::Currency        qw( get_currencies_from_config );


sub setup : Test( setup => no_plan ) {
    my $test = shift;
    $test->{mech}->login_ok;

    $test->{operator} = Test::XTracker::Data->get_schema
                                            ->resultset('Public::Operator')
                                            ->find({username => 'it.god'}, {key => 'username'});

    $test->{mech}->grant_permissions( {
        operator    => $test->{operator}->username,
        perms       => {
            $AUTHORISATION_LEVEL__READ_ONLY => [
                'Finance/Store Credits'
            ],
        },
    } );

    my $chan = Test::XTracker::Data->get_local_channel;
    my $id = Test::XTracker::Data->create_test_customer(
        channel_id => $chan->id
    );
    $test->{customer} = Test::XTracker::Data->get_schema
                                            ->resultset('Public::Customer')
                                            ->find($id);

    my (undef,$pids) = Test::XTracker::Data->grab_products({
        how_many => 1,
        channel_id => $chan->id,
    });

    ($test->{order}) = Test::XTracker::Data->create_db_order({pids => $pids});

    $test->{currency_code}  = config_var('Currency','local_currency_code');

    $test->{ccua} = NAP::CustomerCredit::TestUserAgent->new;

    return;
}

sub test_view_credit_logs : Tests {
    my $test = shift;
    my $cust = $test->{customer};

    $test->{ccua}->clear_requests;
    $test->{ccua}->clear_responses;
    $test->{ccua}->set_response_simple(
        'get',
        $cust->pws_customer_id,
        200,
        {data=>[{
            currencyCode=>$test->{currency_code},
            credit => '123.45',
        }]},
    );
    $test->{ccua}->set_response_simple(
        'get',
        $cust->pws_customer_id.'/'.$test->{currency_code}.'/deltas',
        200,
        {data =>[
            {   type => 'ADJUSTED',
                createdBy => "xt-$APPLICATION_OPERATOR_ID",
                date => { iso8601 => '2010-07-13T12:07:07+01:00' },
                delta => -20,
                notes => 'Manual test adjustment',
            },
            {   type => 'ORDERED',
                createdBy => "xt-$APPLICATION_OPERATOR_ID",
                date => { iso8601 => '2010-07-12T16:39:03+01:00' },
                orderNumber => $test->{order}->order_nr,
                delta => 123.45,
                notes => 'Order - 777',
            },
        ]},
    );

    my $mech = $test->{mech};
    $mech->get_ok('/Finance/StoreCredits/' . $cust->id);

    cmp_deeply([$test->{ccua}->get_requests],
               bag(
                   methods(uri=>methods(as_string=>re('/'.$cust->pws_customer_id.'$'))),
                   methods(uri=>methods(as_string=>re('/'.$cust->pws_customer_id.'/'.$test->{currency_code}.'/deltas$'))),
               ),
               'API called correctly');

    is( $mech->findvalue( q{//*[contains(@class, 'customer_nr')]} ),
        $cust->pws_customer_id,
        "Customer Number present in page" );

    is( $mech->findvalue( q{//*[contains(@class, 'customer_name')]} ),
        $cust->display_name,
        "Customer Name present in page" );

    is( $mech->findvalue( q{//*[contains(@class, 'balance')]} ),
        '123.450 ' . $test->{currency_code},
        "Balance present in page" );

    # Now check the logs.
    my $log = $test->credit_logs_from_table;

    eq_or_diff( $log, [
        {   date => '2010-07-13 12:07',
            operator => 'Application',
            action => 'Manual test adjustment',
            change => '-20.000',
            balance => '123.450',
            link => undef,
        },
        {   date => '2010-07-12 16:39',
            operator => 'Application',
            action => 'Order - 777',
            change => '123.450',
            balance => '143.450',
            link => {
                text => 'View Order',
                href => 'http://localhost/CustomerCare/OrderSearch/OrderView?order_id=' . $test->{order}->id,
            }
        },
    ], "Store Credit log table" );
}

sub test_manual_credit_adjustment : Tests {
    my $test = shift;
    my $cust = $test->{customer};

    $test->{ccua}->clear_requests;
    $test->{ccua}->clear_responses;
    $test->{ccua}->set_response_simple(
        'get',
        $cust->pws_customer_id,
        200,
        {data=>[{
            currencyCode=>$test->{currency_code},
            credit => '0',
        }]},
    );
    $test->{ccua}->set_response_simple(
        'get',
        $cust->pws_customer_id.'/'.$test->{currency_code}.'/deltas',
        200,
        {data =>[]},
    );

    my $mech = $test->{mech};
    $mech->get_ok('/Finance/StoreCredits/' . $cust->id . '/edit');
    cmp_deeply([$test->{ccua}->get_requests],
               bag(
                   methods(uri=>methods(as_string=>re('/'.$cust->pws_customer_id.'$'))),
                   methods(uri=>methods(as_string=>re('/'.$cust->pws_customer_id.'/'.$test->{currency_code}.'/deltas$'))),
               ),
               'API called correctly');

    my $value = '12.34';
    my $notes = 'Notes field value';

    $test->{ccua}->clear_requests;
    $test->{ccua}->clear_responses;
    $test->{ccua}->set_response_simple(
        'post',
        $cust->pws_customer_id.'/'.$test->{currency_code},
        200,
        {data=>{credit=>0+$value}},
    );
    $test->{ccua}->set_response_simple(
        'get',
        $cust->pws_customer_id,
        200,
        {data=>[{
            currencyCode=>$test->{currency_code},
            credit => $value,
        }]},
    );
    $test->{ccua}->set_response_simple(
        'get',
        $cust->pws_customer_id.'/'.$test->{currency_code}.'/deltas',
        200,
        {data =>[
            {   type => 'ADJUSTED',
                createdBy => 'xt-'.$test->{operator}->id,
                date => { iso8601 => '2010-07-13T12:07:07+01:00' },
                delta => $value + 0,
                notes => $notes,
            },
        ]},
    );

    $mech->submit_form_ok({
        with_fields => {
            notes => $notes,
            value => $value,
        }
    }, "Update customer credit form");

    cmp_deeply([$test->{ccua}->get_requests],
               bag(
                   methods(uri=>methods(as_string=>re('/'.$cust->pws_customer_id.'/'.$test->{currency_code}.'/deltas$'))),
                   methods(uri=>methods(as_string=>re('/'.$cust->pws_customer_id.'$'))),
                   methods(uri=>methods(as_string=>re('/'.$cust->pws_customer_id.'/'.$test->{currency_code}.'$')),
                       method=>'POST'),
               ),
               'API called correctly');

    my $operator_name = $test->{operator}->name;
    $operator_name =~ s/\s+/ /g;
    eq_or_diff( $test->credit_logs_from_table, [
        {   date => '2010-07-13 12:07',
            operator => $operator_name,
            action => $notes,
            change => '12.340',
            balance => '12.340',
            link => undef,
        },
    ], "Store Credit log table" );
}

=head2 test_create_store_credit

Verifies that the currencies available to select on the Create Store Credit
page match the currencies listed in config.

=cut

sub test_create_store_credit : Tests {
    my $test    = shift;

    my $mech    = $test->{mech};

    $mech->get_ok('/Finance/StoreCredits');
    $mech->follow_link_ok( { text => 'Create Store Credit' }, 'Create Store Credit link' );

    my $pg_data = $mech->as_data->{page_data};

    my %expect_currencies   = map { $_->{id} => $_->{name} }
                                @{ get_currencies_from_config( $test->{schema} ) };
    my %got_currencies      = map { $_->[0] => $_->[1] }
                                @{ $pg_data->{Currency}{select_values} };
    is_deeply( \%got_currencies, \%expect_currencies, "Expected Currencies shown on page" );
}

sub credit_logs_from_table {
    my ($test) = @_;

    my ($table) = $test->{mech}->findnodes( q{//table[contains(@class, 'customer_credit_log')]} );
    return [] unless $table;

    my $ret = [];

    for my $tr ( $table->findnodes( q{tbody/tr} ) ) {
        my ($date, $operator, $action, $change, $balance, $link) = $tr->findnodes( q{td} );

        $link = $link->getFirstChild;

        push @$ret, {
            date => $date->getValue,
            operator => $operator->getValue,
            action => $action->getValue,
            change => $change->getValue,
            balance => $balance->getValue,
            link => $link->isTextNode
                    ? undef
                    : { href => $link->attr('href'), text => $link->getValue }
        };
    }
    return $ret;
}

Test::Class->runtests;
