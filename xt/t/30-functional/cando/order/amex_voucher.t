#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Data::UUID;

use Test::XTracker::Data;
use Test::XTracker::Data::Order;
use Test::XTracker::Data::AccessControls;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw( :order_status :authorisation_level );
use Test::XT::Flow;


my $schema      = Test::XTracker::Data->get_schema();

note "TEST AMEX Voucher Only";


my ($channel,$pids) = Test::XTracker::Data->grab_products({
    how_many => 4,
    channel => 'NAP',
});

my $framework = Test::XT::Flow->new_with_traits( {
    traits => [
        'Test::XT::Flow::Finance',
    ],
} );

my $mech = $framework->mech;

$framework->login_with_roles( {
    paths => [
        '/Finance/CreditHold',
        '/Finance/CreditCheck',
    ],
} );

my $ra_tests = [
    # original 'AMEX' source code tests
    {
        status_id   => $ORDER_STATUS__CREDIT_CHECK,
        url         => '/Finance/CreditCheck',
        source_code => 'AMEX',
    },
    {
        status_id   => $ORDER_STATUS__CREDIT_HOLD,
        url         => '/Finance/CreditHold',
        source_code => 'AMEX',
    },

    # new tests with 'AMEX' at the start of the source code
    {
        status_id   => $ORDER_STATUS__CREDIT_CHECK,
        url         => '/Finance/CreditCheck',
        source_code => 'AMEX-CAN-1',
    },
    {
        status_id   => $ORDER_STATUS__CREDIT_HOLD,
        url         => '/Finance/CreditHold',
        source_code => 'AMEX-CAN-1',
    },
    {
        status_id   => $ORDER_STATUS__CREDIT_CHECK,
        url         => '/Finance/CreditCheck',
        source_code => 'AmEx-CAN-1',        # case in-sensitive tests
    },
    {
        status_id   => $ORDER_STATUS__CREDIT_HOLD,
        url         => '/Finance/CreditHold',
        source_code => 'AmEx-CAN-1',        # case in-sensitive tests
    },
    # these should fail as 'AMEX' is not at the start
    {
        to_fail     => 1,
        status_id   => $ORDER_STATUS__CREDIT_CHECK,
        url         => '/Finance/CreditCheck',
        source_code => 'xAMEX-CAN-1',
    },
    {
        to_fail     => 1,
        status_id   => $ORDER_STATUS__CREDIT_HOLD,
        url         => '/Finance/CreditHold',
        source_code => 'xAMEX-CAN-1',
    },
];

foreach my $rh_test (@$ra_tests) {
    note "Testing: ".$rh_test->{url}." for Source: ".$rh_test->{source_code};
    my $order_id = create_test_order($channel->id, $pids, $rh_test->{status_id}, $rh_test->{source_code});
    $mech->get($rh_test->{url});
    my $found = $mech->find_xpath('//td[@class="highlight2"]/a[@href="'.$rh_test->{url}.'/OrderView?order_id='.$order_id.'"]');
    if ( !exists( $rh_test->{to_fail} ) ) {
        ok(scalar($found->get_nodelist), "$order_id is in class 'highlight2'");
    }
    else {
        ok( !scalar($found->get_nodelist), "$order_id is NOT in class 'highlight2'");
    }
}

Test::XTracker::Data::AccessControls->restore_build_main_nav_setting;

done_testing;

sub create_test_order {
    my ($channel_id, $pids, $status, $source_code)  = @_;

    my $voucher_code = 'VC-'.Data::UUID->new->create_hex; # a unique ID
    my $rs_voucher = Test::XTracker::Data->create_voucher( { is_physical => 0, name => 'AMEX test: '.$voucher_code } );
    # Create a related code
    my $vi = $rs_voucher->add_code($voucher_code, {source => $source_code} );

    my $rh_items = {
            $pids->[0]{sku} => { price => 100.00, tax => 10, duty => 5},
            $pids->[1]{sku} => { price => 320.00, tax => 10, duty => 5},
            $pids->[2]{sku} => { price => 320.00, tax => 10, duty => 5},
            $pids->[3]{sku} => { price => 500.00, tax => 10, duty => 5},
    };

    #note(p($rh_items));

    my $order = Test::XTracker::Data->do_create_db_order({
        tenders         => [ { type => 'voucher_credit', value => 390, voucher_code_id => $vi->id } ],
        order_status_id => $status,
        channel_id      => $channel_id,
        items           => $rh_items,
    });

    ok ($order, 'created order Id/Nr: '.$order->id.'/'.$order->order_nr);
    return $order->id;
}
