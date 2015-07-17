#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::Data;
use Test::XTracker::MessageQueue;

use base 'Test::Class';

my $po_number = 'TEST_ABC123XYZ';

my $DC = Test::XTracker::Data->whatami();

sub setup : Test(setup) {
    my $test = shift;
    my $schema = Test::XTracker::Data->get_schema;

    my @channels = $schema->resultset('Public::Channel')->search(
        { 'business.fulfilment_only' => 0 },
        { join => 'business' }
    )->all;
    $test->{channels} = \@channels;

    foreach ( @channels ) {
        my $po_num = $po_number.$_->id;
        $schema->resultset('Public::PurchaseOrder')
            ->search({purchase_order_number => $po_num})
            ->delete;
        $schema->resultset('Voucher::PurchaseOrder')
            ->search({purchase_order_number => $po_num})
            ->delete;

        my $code_rs = $schema->resultset('Voucher::Code')
            ->search({ code => {
                -in => [ 'a'.$_->id, 'b'.$_->id, 'c'.$_->id, 'd'.$_->id, 'e'.$_->id, 'f'.$_->id ]
            } });
        $code_rs->related_resultset('credit_logs')->delete;
        $code_rs->delete;
    }

    ($test->{mq},$test->{app}) = Test::XTracker::MessageQueue->new_with_app;
    $test->{schema} = $schema;
}

sub test_voucher_po_import : Tests {
    my $test = shift;
    my $schema = $test->{schema};

    foreach ( @{$test->{channels}} ) {
        my $po_num = $po_number . $_->id;
        note "Testing on channel: " . $_->name;

        my $id = $schema->storage->dbh_do( sub {
            my ($storage, $dbh) = @_;
            my $x = $dbh->selectall_arrayref(
                "SELECT nextval('purchase_order_id_seq')"
            );
            return $x->[0][0];
        });

        my $v1 = Test::XTracker::Data->create_voucher({ channel_id => $_->id });
        my $v2 = Test::XTracker::Data->create_voucher({ channel_id => $_->id });

        my $res = $test->{mq}->request(
            $test->{app},
            "/queue/$DC/product",
            {
                #'@type' => 'purchase_order',
                id => $id,
                po_number => $po_num,
                channel_id => $_->id,
                date => DateTime->now,
                created_by => 1,
                status => 'On Order',
                vouchers => [
                    { pid => $v1->id,
                      codes => [ 'a'.$_->id, 'b'.$_->id, 'c'.$_->id ],
                  },
                    { pid => $v2->id,
                      codes => [ 'd'.$_->id, 'e'.$_->id, 'f'.$_->id ],
                  },
                ],
            },{
                type => 'purchase_order',
            },
        );

        ok $res->is_success, "Create message processed ok";

        my $po = $schema->resultset('Public::SuperPurchaseOrder')
                        ->search({purchase_order_number => $po_num})
                        ->next;

        isa_ok($po, 'XTracker::Schema::Result::Voucher::PurchaseOrder', "Voucher PO created");

        ok($po->currency, "PO has a currency");

        # Each code = one voucher ordered.
        is($po->quantity_ordered, 6, 'correct PO quantity ordered');

        my @prods = $po->vouchers->all;
        is(@prods, 2, "PO linked to two products");

        eq_or_diff(
            [ sort $v1->codes->get_column('code')->all ],
            [ sort ('a'.$_->id, 'b'.$_->id, 'c'.$_->id) ],
            "Codes associated with voucher"
        );

        eq_or_diff(
            [ sort $v2->codes->get_column('code')->all ],
            [ sort ('d'.$_->id, 'e'.$_->id, 'f'.$_->id) ],
            "Codes associated with voucher"
        );

        my $stock_orders = $po->stock_orders;
        my $so = $stock_orders->search({ voucher_product_id => $v1->id })->first;

        ok($so, "StockOrder for voucher 1");
        eq_or_diff(
        [ sort $so->get_voucher_codes->get_column('code')->all],
        [ sort $v1->codes->get_column('code')->all ],
        "Codes linked to the stock order"
        );

        $so = $stock_orders->search({ voucher_product_id => $v2->id })->first;

        ok($so, "StockOrder for voucher 2");
        eq_or_diff(
        [ sort $so->get_voucher_codes->get_column('code')->all ],
        [ sort $v2->codes->get_column('code')->all ],
        "Codes linked to the stock order"
        );
    }
}

sub test_voucher_po_import_with_channel_not_in_this_dc : Tests {
    my $test = shift;
    my $v1 = Test::XTracker::Data->create_voucher;

    # Send a message on a channel that isn't in *any* DC. Beter not be a
    # channel 999999 else we're in trouble ;)
    my $res = $test->{mq}->request(
        $test->{app},
        "/queue/$DC/product",
        {
            #'@type' => 'purchase_order',
            id => 1, # This id shouldn't be used, so we can put what ever
            po_number => $po_number,
            channel_id => 999999,
            date => DateTime->now,
            created_by => 1,
            status => 'On Order',
            vouchers => [
                { pid => $v1->id,
                  codes => [ qw/a b c/ ],
              },
            ],
        },{
            type => 'purchase_order',
        },
    );

    ok $res->is_success, "Create message processed ok" or pp($res);

    my $po = $test->{schema}->resultset('Public::SuperPurchaseOrder')
                    ->search({purchase_order_number => $po_number})
                    ->next;

    is($po, undef, "Voucher PO not created");
}

sub test_voucher_po_cancel : Tests {
    my $test = shift;
    my $voucher = Test::XTracker::Data->create_voucher;
    my $vpo = Test::XTracker::Data->setup_purchase_order($voucher->id);

    # Now that we've created it, cancel it. Ha
    my $res = $test->{mq}->request(
        $test->{app},
        "/queue/$DC/product",
        {
            #'@type' => 'purchase_order',
            id => $vpo->id,
            po_number => $vpo->purchase_order_number,
            channel_id => Test::XTracker::Data->channel_for_business(name=>'nap')->id,
            date => DateTime->now,
            created_by => 1,
            status => 'Cancelled',
            vouchers => [ ],
        },{
            type => 'purchase_order',
        },
    );
    ok $res->is_success, "Cancel message processed ok";
    ok($vpo->discard_changes->is_cancelled, "PO cancelled");
}

Test::Class->runtests;
