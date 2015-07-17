#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use Test::XTracker::LoadTestConfig;
use Test::XTracker::MessageQueue;
use Test::XTracker::Data;
use String::Random;

use XTracker::Constants   qw( :application );

use XTracker::Constants::FromDB qw(
    :currency
    :renumeration_class
    :renumeration_status
    :renumeration_type
);
use XTracker::Database::Invoice;
use XTracker::Config::Local         qw( config_section_slurp );

use base 'Test::Class';

sub create_voucher_code {
    my ( $self, $voucher ) = @_;

    my $sr = String::Random->new;
    my $c = 'SCR-'.$sr->randregex('[A-Z]{8}');
    return $voucher->add_code($c);
}

sub clear_warning {
    my $self    = shift;
    $self->{warning}    = 0;
    $self->{warnmsg}    = '';
}

# tests that a warning was/was not issued
sub test_warning {
    my ( $self, $msg ) = @_;
    if ( $msg ) {
        cmp_ok( $self->{warning}, '>', 0, "Warning Issued" );
        like( $self->{warnmsg}, qr/$msg/, "Warning Message like as expected: ".$msg );
    }
    else {
        cmp_ok( $self->{warning}, '==', 0, "Warning NOT Issued" );
    }
}

sub create_order {
    my ( $self, $args ) = @_;
    my ( $channel, $pids ) = Test::XTracker::Data->grab_products({
        how_many => 1, channel => 'nap'
    });
    my ($order) = Test::XTracker::Data->apply_db_order({
        pids => $pids,
        attrs => [ { price => $args->{price} }, ],
        base => {
            shipping_charge => 0,
            tenders => $args->{tenders},
        },
    });
    $self->clear_warning;
    note "Order Nr/Id: ".$order->order_nr."/".$order->id;
    return $order;
}

sub create_renumeration_for {
    my ( $self, $order, $value_args ) = @_;
    my $dbh = Test::XTracker::Data->get_schema->storage->dbh;
    my $renumeration = $order->shipments->first->add_to_renumerations({
        invoice_nr => XTracker::Database::Invoice::generate_invoice_number($dbh),
        renumeration_type_id => $RENUMERATION_TYPE__STORE_CREDIT,
        renumeration_class_id => $RENUMERATION_CLASS__RETURN,
        renumeration_status_id => $RENUMERATION_STATUS__PENDING,
        currency_id => $CURRENCY__GBP,
        sent_to_psp => 1,
    });
    $renumeration->discard_changes;

    my $ship_item   = $order->shipments->first->shipment_items->first;

    my $total_value = 0;
    for my $tender ( $order->tenders->all ) {
        my $value;

        if($tender->type_id == $RENUMERATION_TYPE__VOUCHER_CREDIT) {
            $value = $value_args->{voucher_credit}{$tender->voucher_code->code}
        } else {
            $value = $value_args->{store_credit};
        }

        $renumeration->add_to_tenders( $tender, { value => $value });

        $total_value    += $value;
    }

    $renumeration->create_related( 'renumeration_items', {
                                            shipment_item_id    => $ship_item->id,
                                            unit_price          => $total_value,
                                            tax                 => 0,
                                            duty                => 0,
                                    } );
    return $renumeration;
}

sub startup : Tests(startup => 1) {
    my $test = shift;
    ## no critic(RequireLocalizedPunctuationVars)
    # shouldn't really modify signal handlers globally
    $SIG{'__WARN__'} = sub { $test->{warning} = 1; $test->{warnmsg} = shift; };
    $test->{voucher} = Test::XTracker::Data->create_voucher;
}

sub setup : Test(setup) {
    my $test = shift;
    $test->{sender}=Test::XTracker::MessageQueue->new;
    my $channel = Test::XTracker::Data->get_local_channel();
    $test->{queue_name} = '/queue/refund-integration-'.$channel->web_queue_name_part;
    $test->{sender}->clear_destination( $test->{queue_name} );

    # get an operator id that is not $APPLICATION_OPERATOR_ID
    my $schema  = Test::XTracker::Data->get_schema;
    my $operator= $schema->resultset('Public::Operator')
                                ->search( { 'me.id' => { '!=' => $APPLICATION_OPERATOR_ID } }, { rows => 1 } )
                                ->first;
    $test->{operator}   = $operator;
    # the operator id should be prefixed by 'xt-' so that it can
    # be spotted when being displayed on the store credit logs page
    $test->{xt_op_id}   = 'xt-'.$operator->id;
}

sub test_voucher_refund : Tests {
    my $test = shift;
    my $voucher_code = $test->create_voucher_code($test->{voucher});
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'voucher_credit',
            value => 100,
            voucher_code_id  => $voucher_code->id,
        }],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        voucher_credit => { $voucher_code->code => 100 }
    });

    # Link order's tenders to renumeration
    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => [superhashof({
                '@type'     => 'CustomerCreditRefundValueRequestDTO',
                refundValue       => '100.000',
                voucherCode => $voucher_code->code,
            })],
        }),
    }, 'full refund voucher message ok');

    # check no warning was issued
    $test->test_warning;
}

sub test_multiple_voucher_refund : Tests {
    my $test = shift;
    my @voucher_codes;
    push @voucher_codes, $test->create_voucher_code($test->{voucher})
        for (0..1);
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'voucher_credit',
            value => 40,
            voucher_code_id  => $voucher_codes[0]->id,
        },
        {
            type  => 'voucher_credit',
            value => 60,
            voucher_code_id  => $voucher_codes[1]->id,
        },],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        voucher_credit => {
            $voucher_codes[0]->code => 40,
            $voucher_codes[1]->code => 60,
        }
    });
    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => bag(
                superhashof({
                    '@type' => 'CustomerCreditRefundValueRequestDTO',
                    refundValue => '40.000',
                    voucherCode => $voucher_codes[0]->code,
                }),
                superhashof({
                    '@type' => 'CustomerCreditRefundValueRequestDTO',
                    refundValue => '60.000',
                    voucherCode => $voucher_codes[1]->code,
                }),
            ),
        }),
    }, 'full refund voucher message ok');

    # check no warning was issued
    $test->test_warning;
}

sub test_store_credit_refund : Tests {
    my $test = shift;
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'store_credit',
            value => 100,
        }],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        store_credit => 100
    });
    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => [superhashof({
                '@type' => 'CustomerCreditRefundValueRequestDTO',
                refundValue => '100.000',
            })],
        }),
    }, 'full refund store credit message ok');

    # check no warning was issued
    $test->test_warning;
}

sub test_alt_customer_store_credit_refund : Tests {
    my $test = shift;
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'store_credit',
            value => 100,
        }],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        store_credit => 100
    });
    $renumeration->update( { alt_customer_nr => 123456 } );
    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => '123456',
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => [superhashof({
                '@type' => 'CustomerCreditRefundValueRequestDTO',
                refundValue => '100.000',
            })],
        }),
    }, 'full refund store credit message ok');

    # check no warning was issued
    $test->test_warning;
}

sub test_mixed_refund : Tests {
    my $test = shift;
    my $voucher_code = $test->create_voucher_code($test->{voucher});
    my $order = $test->create_order({
        price => 100,
        tenders => [
            {
                type  => 'store_credit',
                value => 40,
            },
            {
                type  => 'voucher_credit',
                value => 60,
                voucher_code_id => $voucher_code->id,
            },
        ],
    });
    my $renumeration = $test->create_renumeration_for( $order, {
        store_credit => 40,
        voucher_credit => { $voucher_code->code => 60, },
    });
    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => bag(
                superhashof({
                    '@type' => 'CustomerCreditRefundValueRequestDTO',
                    refundValue => '40.000',
                }),
                superhashof({
                    '@type' => 'CustomerCreditRefundValueRequestDTO',
                    refundValue => '60.000',
                    voucherCode => $voucher_code->code,
                })
            ),
        }),
    }, 'full refund store credit message ok');

    # check no warning was issued
    $test->test_warning;
}

sub test_no_operator_id_should_use_app_id : Tests {
    my $test = shift;
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'store_credit',
            value => 100,
        }],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        store_credit => 100
    });

    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => 'xt-'.$APPLICATION_OPERATOR_ID,
            refundCurrency => $renumeration->currency->currency,
            refundValues => [superhashof({
                '@type' => 'CustomerCreditRefundValueRequestDTO',
                refundValue => '100.000',
            })],
        }),
    }, 'full refund store credit message ok');

    # check no warning was issued
    $test->test_warning;
}

sub test_renumeration_tender_value_greater_than_invoice_value : Tests {
    my $test = shift;
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'store_credit',
            value => 100,
        }],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        store_credit => 100
    });

    # adjust the renumeration tender to be more than the invoice value
    $renumeration->renumeration_tenders->first->update( { value => 200 } );

    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => [superhashof({
                '@type' => 'CustomerCreditRefundValueRequestDTO',
                refundValue => '100',
            })],
        }),
    }, 'Store Credit is for the Invoice amount and not the Total Renumeration Tenders');

    # check a warning was issued
    $test->test_warning( "WARN StoreCreditRefund: Renumeration Tender gtr than Invoice" );
}

sub test_single_gift_voucher_renumeration_tender_vaule_greater_than_invoice_value : Tests {
    my $test = shift;
    my $voucher_code = $test->create_voucher_code($test->{voucher});
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'voucher_credit',
            value => 100,
            voucher_code_id  => $voucher_code->id,
        }],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        voucher_credit => { $voucher_code->code => 100 }
    });

    # adjust the renumeration tender to be more than the invoice value
    $renumeration->renumeration_tenders->first->update( { value => 200 } );

    # Link order's tenders to renumeration
    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => [superhashof({
                '@type'     => 'CustomerCreditRefundValueRequestDTO',
                refundValue       => '100',
                voucherCode => $voucher_code->code,
            })],
        }),
    }, 'Credit is for the Invoice amount and Voucher Code is used');

    # check a warning was issued
    $test->test_warning( "WARN StoreCreditRefund: Renumeration Tender gtr than Invoice" );
}

sub test_mixed_renumeration_tender_value_greater_than_invoice_value : Tests {
    my $test = shift;
    my $voucher_code = $test->create_voucher_code($test->{voucher});
    my $order = $test->create_order({
        price => 100,
        tenders => [
            {
                type  => 'store_credit',
                value => 40,
            },
            {
                type  => 'voucher_credit',
                value => 60,
                voucher_code_id => $voucher_code->id,
            },
        ],
    });
    my $renumeration = $test->create_renumeration_for( $order, {
        store_credit => 40,
        voucher_credit => { $voucher_code->code => 60, },
    });

    # adjust the renumeration tenders to be more than the invoice value
    my @tmp = $renumeration->renumeration_tenders->search( {}, { order_by => 'me.tender_id' } )->all;
    $tmp[0]->update( { value => 50 } );     # store credit tender
    $tmp[1]->update( { value => 70 } );     # voucher credit tender

    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => [
                all(
                    superhashof({
                        '@type' => 'CustomerCreditRefundValueRequestDTO',
                        refundValue => '100',
                    }),
                    code(sub { ! exists shift->{voucherCode} } ),
                ),
            ],
        }),
    }, 'Store Credit is used and for Invoice Amount and the Voucher Code is not given');

    # check a warning was issued
    $test->test_warning( "WARN StoreCreditRefund: Renumeration Tender gtr than Invoice" );
}

sub test_multiple_voucher_renumeration_tender_value_greater_than_invoice_value : Tests {
    my $test = shift;
    my @voucher_codes;
    push @voucher_codes, $test->create_voucher_code($test->{voucher})
        for (0..1);
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'voucher_credit',
            value => 40,
            voucher_code_id  => $voucher_codes[0]->id,
        },
        {
            type  => 'voucher_credit',
            value => 60,
            voucher_code_id  => $voucher_codes[1]->id,
        },],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        voucher_credit => {
            $voucher_codes[0]->code => 40,
            $voucher_codes[1]->code => 60,
        }
    });

    # adjust the renumeration tenders to be more than the invoice value
    my @tmp = $renumeration->renumeration_tenders->search( {}, { order_by => 'me.tender_id' } )->all;
    $tmp[0]->update( { value => 50 } );
    $tmp[1]->update( { value => 70 } );

    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => [
                all(
                    superhashof({
                        '@type' => 'CustomerCreditRefundValueRequestDTO',
                        refundValue => '100',
                    }),
                    code(sub { ! exists shift->{voucherCode} } ),
                ),
            ],
        }),
    }, 'Store Credit is used and for Invoice Amount and neither Voucher Code is given');

    # check a warning was issued
    $test->test_warning( "WARN StoreCreditRefund: Renumeration Tender gtr than Invoice" );
}

sub test_mixed_with_no_renumeration_tenders : Tests {
    my $test = shift;
    # tests that with no renumeration tenders it still produces
    # a valid message

    my $voucher_code = $test->create_voucher_code($test->{voucher});
    my $order = $test->create_order({
        price => 100,
        tenders => [
            {
                type  => 'store_credit',
                value => 40,
            },
            {
                type  => 'voucher_credit',
                value => 60,
                voucher_code_id => $voucher_code->id,
            },
        ],
    });
    my $renumeration = $test->create_renumeration_for( $order, {
        store_credit => 40,
        voucher_credit => { $voucher_code->code => 60, },
    });

    # delete all renumeration tenders
    $renumeration->renumeration_tenders->delete();

    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            refundValues => [
                all(
                    superhashof({
                        '@type' => 'CustomerCreditRefundValueRequestDTO',
                        refundValue => '100',
                    }),
                    code(sub { ! exists shift->{voucherCode} } ),
                ),
            ],
        }),
    }, 'Store Credit is still given even without any Renumeration Tenders');

    # check no warning was issued
    $test->test_warning;
}

sub test_gratuity_store_credit_refund : Tests {
    my $test = shift;
    # this tests a renumeration with a class of GRATUITY
    # produces the correct message
    my $order = $test->create_order({
        price => 100,
        tenders => [{
            type  => 'store_credit',
            value => 100,
        }],
    });

    my $renumeration = $test->create_renumeration_for( $order, {
        store_credit => 100
    });

    # update the class to be Gratuity
    $renumeration->update( { renumeration_class_id => $RENUMERATION_CLASS__GRATUITY } );

    # delete all renumeration tenders as there wouldn't be any for Gratuities
    $renumeration->renumeration_tenders->delete();

    $test->{sender}->transform_and_send('XT::DC::Messaging::Producer::Order::StoreCreditRefund', { renumeration => $renumeration, operator_id => $test->{operator}->id } );
    $test->{sender}->assert_messages({
        destination => $test->{queue_name},
        filter_header => superhashof({
            type => 'RefundRequestMessage',
        }),
        assert_body => superhashof({
            '@type' => 'CustomerCreditRefundRequestDTO',
            orderId => $order->order_nr,
            customerId => $order->customer->is_customer_number,
            createdBy => $test->{xt_op_id},
            refundCurrency => $renumeration->currency->currency,
            notes => 'Gratuity',
            refundValues => [all(
                superhashof({
                    '@type' => 'CustomerCreditRefundValueRequestDTO',
                    refundValue => '100',
                }),
                code(sub{ ! exists shift->{voucherCode} }),
            )],
        }),
    }, 'refund message ok for Gratuity');

    # check no warning was issued
    $test->test_warning;
}

Test::Class->runtests;
