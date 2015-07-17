#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use Test::XTracker::Hacks::isaFunction;
use JSON::XS;

use Test::XTracker::Data;
use Test::XTracker::MessageQueue;
use DateTime;

use base 'Test::Class';

use XT::Domain::PRLs;
use XTracker::Constants::FromDB qw{ :channel };
use XTracker::Constants qw( :application );
use XTracker::Config::Local         qw{ config_var };
use Test::XTracker::RunCondition  export => [qw/$prl_rollout_phase/];

my $DC          = Test::XTracker::Data->whatami();

sub create_voucher {
    return Test::XTracker::Data->create_voucher( { %{ $_[1] } } );
}

sub currency_id_from_code {
    my ( $self, $code ) = @_;
    return Test::XTracker::Data->get_schema
                                ->resultset('Public::Currency')
                                ->search({currency=>$code})
                                ->slice(0,0)
                                ->single
                                ->id;
}

sub startup : Tests(startup => 2) {
    my $test = shift;
    $test->{schema} = Test::XTracker::Data->get_schema;
    ($test->{mq},$test->{app}) = Test::XTracker::MessageQueue->new_with_app;
}

sub setup : Tests(setup) {
    my $test = shift;
    my @channels = $test->{schema}->resultset('Public::Channel')->search(
        { 'business.fulfilment_only' => 0 },
        { join => 'business' }
    )->all;

    my $i = 0;
    foreach ( @channels ) {
        my $id = Test::XTracker::Data->next_id([qw{voucher.product product}])+$i;
        my $variant_id
            = Test::XTracker::Data->next_id([qw{voucher.variant variant}])+$i;

        $test->{channels}{$_->web_name}=$_;

        $test->{voucher_params}{$_->web_name} = {
            id                       => $id,
            variant_id               => $variant_id,
            channel_id               => $_->id,
            name                     => "Test Voucher $id",
            landed_cost              => 1.00,
            value                    => 100,
            currency_code            => 'GBP',
            is_physical              => JSON::XS::false,
            created                  => DateTime->now,
            disable_scheduled_update => JSON::XS::false,
            operator_id              => $APPLICATION_OPERATOR_ID,
            visible                  => JSON::XS::false,
        };
        $i++;
    }
    my $code_rs = $test->{schema}
                        ->resultset('Voucher::Code')
                        ->search({
                            code => { -in => [qw{a b}] }
                        });
    $code_rs->related_resultset('credit_logs')->delete;
    $code_rs->delete;
}

sub test_create_voucher : Tests {
    my $test = shift;
    my $schema = $test->{schema};

    while ( my ( $key, $value ) = each %{$test->{voucher_params}} ) {
        $test->clear_test_sku_update;
        my $res = $test->{mq}->request(
            $test->{app},
            "/queue/$DC/product",
            $value,
            { type => 'create_voucher' },
        );
        ok( $res->is_success, 'Create message processed ok' );

        my $voucher = $schema->resultset('Voucher::Product')
                            ->find($test->{voucher_params}{$key}{id});
        isa_ok( $voucher, 'XTracker::Schema::Result::Voucher::Product' );
        cmp_ok( $voucher->variant->id, q{==}, $test->{voucher_params}{$key}{variant_id},
            'variant_id set correctly' );
        $test->test_sku_update($voucher);
    }
}

sub test_update_voucher : Tests {
    my $test = shift;
    while ( my ( $key, $value ) = each %{$test->{voucher_params}} ) {
        my $voucher_params = { %{$test->{voucher_params}{$key}} };

        #my $voucher_params = $value;

        $voucher_params->{currency_id} = $test->currency_id_from_code(
            delete $voucher_params->{currency_code}
        );

        my $voucher = $test->create_voucher($voucher_params);
        $voucher_params->{$_} = $test->{voucher_params}{$key}{$_} = $voucher->$_ + 1
            for (qw<landed_cost value>);

        $test->clear_test_sku_update;
        my $res = $test->{mq}->request(
            $test->{app},
            "/queue/$DC/product",
            $test->{voucher_params}{$key},
            { type => 'update_voucher' },
        );

        ok( $res->is_success, 'Update message processed ok' )
            ||explain $res->content;
        $voucher->discard_changes;

        $test->test_sku_update($voucher);

        # We're not interested in the variant_id
        delete $voucher_params->{variant_id};

        for my $param ( keys %{$voucher_params} ) {
            my $cmp = $voucher->$param =~ m{^[\.\d]+$} ? '==' : 'eq';
            cmp_ok( $voucher->$param, $cmp, $voucher_params->{$param}, "$param correct" )
        }
    }
}

sub test_make_voucher_live : Tests {
    my $test = shift;
    while ( my ( $key, $value ) = each %{$test->{voucher_params}} ) {
        my $voucher_params  = $value;
        my $stock_qty       = 7;

        $voucher_params->{currency_id}
            = $test->currency_id_from_code(delete $voucher_params->{currency_code});

        my $voucher = $test->create_voucher($voucher_params);
        $voucher->update( { upload_date => undef } );   # make sure the upload_date is null
        ok( !defined $voucher->live, 'Voucher live() method indicates NOT live' );

        # get a date for the 'upload_date' field
        my $upload_date = DateTime->now( time_zone => 'local' );

        my $make_live_params    = {
                voucher => {
                    id => $voucher->id,
                    channel_id => $test->{channels}{$key}->id,
                    upload_date => $upload_date,
                },
            };
        # get queue for stock update message
        my $stock_queue = config_var('Producer::Stock::Update','routes_map')
            ->{$key};

        note "Test making live with NO stock";
        $test->{mq}->clear_destination( $stock_queue );       # clear the stock queue ready for check
        my $res = $test->{mq}->request(
            $test->{app},
            "/queue/$DC/product",
            $make_live_params,
            { type => 'make_live' },
        );
        ok( $res->is_success, "no stock: Make Live message for Voucher processed ok" )||explain $res->content;
        $voucher->discard_changes;
        is( $voucher->upload_date, $upload_date, "no stock: 'upload_date' updated correctly (".$voucher->upload_date.")" );
        ok( $voucher->live, 'Voucher live() method indicates LIVE' );

        # check stock update message was sent
        $test->{mq}->assert_messages( {
            destination => $stock_queue,
            assert_header => superhashof({
                type => 'StockUpdate',
            }),
            assert_body => superhashof({
                sku => $voucher->variant->sku,
                quantity_change => 0,
            }),
        }, 'ZERO Stock Update message found with correct SKU & Quantity' );

        note "Test making live WITH stock";
        $voucher->update( { upload_date => undef } );   # make sure the upload_date is null
        # set some stock for the voucher
        Test::XTracker::Data->set_voucher_stock( { voucher => $voucher, quantity => $stock_qty } );
        $test->{mq}->clear_destination( $stock_queue );       # clear the stock queue ready for check
        $res = $test->{mq}->request(
            $test->{app},
            "/queue/$DC/product",
            $make_live_params,
            { type => 'make_live' },
        );
        ok( $res->is_success, "with stock: Make Live message for Voucher processed ok" );
        $voucher->discard_changes;
        is( $voucher->upload_date, $upload_date, "with stock: 'upload_date' updated correctly (".$voucher->upload_date.")" );

        # check stock update message was sent
        $test->{mq}->assert_messages( {
            destination => $stock_queue,
            assert_header => superhashof({
                type => 'StockUpdate',
            }),
            assert_body => superhashof({
                sku => $voucher->variant->sku,
                quantity_change => $stock_qty,
            }),
        }, 'Stock Update message with stock found with correct SKU & Quantity' );

        # send the request again but with a different upload date and it should be ignored
        note "Test subsequent make live requests are ignored";
        $make_live_params->{voucher}{upload_date}   = $upload_date + DateTime::Duration->new( days => 2 );
        $test->{mq}->clear_destination( $stock_queue );       # clear the stock queue ready for check
        $res = $test->{mq}->request(
            $test->{app},
            "/queue/$DC/product",
            $make_live_params,
            { type => 'make_live' },
        );
        ok( $res->is_success, "subsequent Make Live message processed ok" );
        $voucher->discard_changes;
        is( $voucher->upload_date, $upload_date, "'upload_date' hasn't changed (".$voucher->upload_date.")" );
        $test->{mq}->assert_messages({
            destination => $stock_queue,
            assert_count => 0,
        }, 'NO Stock Update message sent' );
    }
}

sub test_make_product_live : Tests {
    my $test = shift;
    # this doesn't test much at the moment other than the stucture
    # of the message for a product can be sent ok
    my $make_live_params    = {
            product => {
                id => 123456,
            },
        };

    my $res = $test->{mq}->request(
        $test->{app},
        "/queue/$DC/product",
        $make_live_params,
        { type => 'make_live' },
    );
    ok( $res->is_success, "Make Live message for Product processed ok" );
}

sub test_delete_voucher : Tests {
    my $test = shift;
    while ( my ( $key, $value ) = each %{$test->{voucher_params}} ) {
        my $voucher_params = $value;
        $voucher_params->{currency_id}
            = $test->currency_id_from_code(delete $voucher_params->{currency_code});
        my $voucher = $test->create_voucher( $voucher_params );

        my $res = $test->{mq}->request(
            $test->{app},
            "/queue/$DC/product",
            { id => $test->{voucher_params}{$key}{id} },
            { type => 'delete_voucher' },
        );
        ok( $res->is_success, 'Create message processed ok' );
        $voucher = $test->{schema}->resultset('Voucher::Product')
                                ->find( $test->{voucher_params}{$key}{id} );
        is( $voucher, undef, 'voucher deleted' );
    }
}

sub test_create_orderless_voucher : Tests {
    my $test = shift;
    my $voucher = $test->create_voucher({is_physical=>0});
    my $now = DateTime->now;
    my $po_args = {
        expiry_date         => $now,
        source              => 'source_test',
        send_reminder_email => 1,
        vouchers => [{
            pid   => $voucher->id,
            codes => [ qw{a b} ],
        },],
    };
    my $res = $test->{mq}->request(
        $test->{app},
        "/queue/$DC/product",
        $po_args,
        { type => 'create_orderless_voucher' },
    );
    ok($res->is_success, 'Orderless message processed ok')
        ||explain $res->content;

    my @codes = $voucher->codes->all;
    ok(@codes, 'voucher codes created');

    for my $code ( @codes ) {
        ok( $code->is_active, 'Code has been activated' );
        ok( $code->send_reminder_email, 'Send reminder email ok' );
        cmp_ok( $code->remaining_credit, q{==}, $voucher->value,
            'Code has full voucher value' );
        is( $code->source, $po_args->{source}, "source matches" );
        ok( DateTime->compare($code->expiry_date, $now) == 0,
            'expiry_date matches' );
    }
}

sub clear_test_sku_update {
    my ($test) = @_;

    if ($prl_rollout_phase) {
        my @prls = XT::Domain::PRLs::get_all_prls();
        foreach my $prl (@prls) {
            $test->{mq}->clear_destination($prl->amq_queue);
        }
    }
}

sub test_sku_update {
    my ($test,$voucher) = @_;

    # If PRLs are turned on, we should've sent one message for each related SKU
    # to each PRL
    if ($prl_rollout_phase) {
        my @prls = XT::Domain::PRLs::get_all_prls();
        foreach my $prl (@prls) {
            $test->{mq}->assert_messages({
                destination => $prl->amq_queue,
                filter_header => superhashof({
                    type => 'sku_update',
                }),
                filter_body => superhashof({
                    '@type' => 'sku_update',
                    'sku' => $voucher->variant->sku,
                }),
            },"message found for PRL ". $prl->name ." SKU " .
              $voucher->variant->sku);
        }
    }
}

Test::Class->runtests;
