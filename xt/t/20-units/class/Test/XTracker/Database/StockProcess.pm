package Test::XTracker::Database::StockProcess;
use NAP::policy "tt", "test", "class";
use FindBin::libs;
BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
};

use NAP::policy "tt";
use Test::Differences;
use Test::More::Prefix qw/ test_prefix /;

use Test::XTracker::Data;
use XTracker::Constants::FromDB qw(
    :putaway_type
);

use XTracker::Database::StockProcess qw(get_putaway_type);

sub get_group_id {
    my $self = shift;

    my $product = (Test::XTracker::Data->grab_products({
        how_many=>1,
    }))[1]->[0]{product_channel}->product;
    my $purchase_order = Test::XTracker::Data->setup_purchase_order($product->id);
    my ($delivery) = Test::XTracker::Data->create_delivery_for_po(
        $purchase_order->id,
        "putaway",
    );
    my ($stock_process_row) = Test::XTracker::Data->create_stock_process_for_delivery(
        $delivery,
    );

    return $stock_process_row->group_id;
}

sub test_get_putaway_type : Tests() {
    my $self = shift;

    my $test_cases = [
        {
            prefix => "Nothing",
            setup => { },
            expected => {
                return     => { },
                sub_called => {
                    get_stock_process_items        => 1,
                    get_return_stock_process_items => 1,
                    get_sample_process_items       => 1,
                    get_quarantine_process_items   => 1,
                    get_voucher                    => 1,
                },
            },
        },
        {
            prefix => "Goods In",
            setup => {
                has_stock_process_item => 1,
            },
            expected => {
                return => {
                    putaway_type      => $PUTAWAY_TYPE__GOODS_IN,
                    putaway_type_name => "Goods In",
                },
                sub_called => {
                    get_stock_process_items => 1,
                },
                sub_called_stored => {
                },
            },
        },
        {
            prefix => "Customer Return: Returns",
            setup => {
                has_return_stock_process_item => 1,
                shipment_class                => "-not transfer-",
            },
            expected => {
                return => {
                    putaway_type      => $PUTAWAY_TYPE__RETURNS,
                    putaway_type_name => "Returns",
                    return_id         => 54,
                    return_info       => { shipment_id => 123 },
                    shipment_info     => { class => "-not transfer-" },
                    variant_id        => "123-432",
                },
                sub_called => {
                    get_stock_process_items        => 1,
                    get_return_stock_process_items => 1, #returns
                    get_return_id_by_process_group => 1, #returns
                    get_return_info                => 1, #returns
                    get_shipment_info              => 1, #returns
                },
                sub_called_stored => {
                    get_return_stock_process_items => 1, #returns
                    get_return_id_by_process_group => 1, #returns
                    get_return_info                => 1, #returns
                    get_shipment_info              => 1, #returns
                },
            },
        },
        {
            prefix => "Customer Return: Transfer Shipment",
            setup => {
                has_return_stock_process_item => 1,
                shipment_class                => "Transfer Shipment",
            },
            expected => {
                return => {
                    putaway_type      => $PUTAWAY_TYPE__STOCK_TRANSFER,
                    putaway_type_name => "Stock Transfer",
                    return_id         => 54,
                    return_info       => { shipment_id => 123 },
                    shipment_info     => { class => "Transfer Shipment" },
                    variant_id        => "123-432",
                },
                sub_called => {
                    get_stock_process_items        => 1,
                    get_return_stock_process_items => 1, #returns
                    get_return_id_by_process_group => 1, #returns
                    get_return_info                => 1, #returns
                    get_shipment_info              => 1, #returns
                },
                sub_called_stored => {
                    get_return_stock_process_items => 1, #returns
                    get_return_id_by_process_group => 1, #returns
                    get_return_info                => 1, #returns
                    get_shipment_info              => 1, #returns
                },
            },
        },
        {
            prefix => "Vendor Samples",
            setup => {
                has_get_sample_process_items => 1,
            },
            expected => {
                return => {
                    putaway_type      => $PUTAWAY_TYPE__SAMPLE,
                    putaway_type_name => "Sample",
                    variant_id        => "123-444",
                },
                sub_called => {
                    get_stock_process_items        => 1,
                    get_return_stock_process_items => 1,
                    get_sample_process_items       => 1,
                },
                sub_called_stored => {
                    get_sample_process_items       => 1,
                },
            },
        },
        {
            prefix => "Processed Quarantine",
            setup => {
                has_get_quarantine_process_items => 1,
            },
            expected => {
                return => {
                    putaway_type      => $PUTAWAY_TYPE__PROCESSED_QUARANTINE,
                    putaway_type_name => "Processed Quarantine",
                    variant_id        => "123-444",
                },
                sub_called => {
                    get_stock_process_items        => 1,
                    get_return_stock_process_items => 1,
                    get_sample_process_items       => 1,
                    get_quarantine_process_items   => 1,
                },
                sub_called_stored => {
                    get_quarantine_process_items   => 1,
                },
            },
        },
        {
            prefix => "Voucher",
            setup => {
                has_stock_process_get_voucher => 1,
            },
            expected => {
                return => {
                    putaway_type      => $PUTAWAY_TYPE__GOODS_IN,
                    putaway_type_name => "Goods In",
                },
                sub_called => {
                    get_stock_process_items        => 1,
                    get_return_stock_process_items => 1,
                    get_sample_process_items       => 1,
                    get_quarantine_process_items   => 1,
                    get_voucher                    => 1,
                },
                sub_called_stored => {
                    # No call because voucher was already identified as a GOODS_IN
                    # get_voucher                    => 1,
                },
            },
        },
    ];

    for my $case (@$test_cases) {
        test_prefix($case->{prefix});
        note "*** Setup";
        my $setup = $case->{setup};
        no warnings "redefine";

        note "Mock relevant subs called in the get_putaway_type sub";
        my $sub_called = {};
        local *XTracker::Database::StockProcess::get_stock_process_items
            = sub {
                $sub_called->{get_stock_process_items}++;
                return ($setup->{has_stock_process_item})
                    ? [ +{ dummy => 1 } ]
                    : [ ];
            };

        local *XTracker::Database::StockProcess::get_return_stock_process_items
            = sub {
                $sub_called->{get_return_stock_process_items}++;
                return ($setup->{has_return_stock_process_item})
                    ? [ +{ variant_id => "123-432" } ]
                    : [ ];
            };
        local *XTracker::Database::StockProcess::get_return_id_by_process_group
            = sub {
                $sub_called->{get_return_id_by_process_group}++;
                return ($setup->{has_return_stock_process_item})
                    ? 54
                    : undef;
            };
        local *XTracker::Database::StockProcess::get_return_info
            = sub {
                $sub_called->{get_return_info}++;
                return ($setup->{has_return_stock_process_item})
                    ? +{ shipment_id => 123 }
                    : +{};
            };
        local *XTracker::Database::StockProcess::get_shipment_info
            = sub {
                $sub_called->{get_shipment_info}++;
                return ($setup->{has_return_stock_process_item})
                    ? +{ class => $setup->{shipment_class} }
                    : +{};
            };

        local *XTracker::Database::StockProcess::get_sample_process_items
            = sub {
                $sub_called->{get_sample_process_items}++;
                return ($setup->{has_get_sample_process_items})
                    ? [ +{ variant_id => "123-444" } ]
                    : [ ];
            };

        local *XTracker::Database::StockProcess::get_quarantine_process_items
            = sub {
                $sub_called->{get_quarantine_process_items}++;
                return ($setup->{has_get_quarantine_process_items})
                    ? [ +{ variant_id => "123-444" } ]
                    : [ ];
            };

        local *XTracker::Schema::ResultSet::Public::StockProcess::get_voucher
            = sub {
                $sub_called->{get_voucher}++;
                return ($setup->{has_stock_process_get_voucher})
                    ? +{ }
                    : undef;
            };


        note "Creating a StockProcess";
        my $group_id = $self->get_group_id();
        test_prefix($case->{prefix});

        note "*** Run: Call get_putaway_type";
        my $putaway_type = get_putaway_type($self->dbh, $group_id);


        note "*** Test";
        my $expected = $case->{expected};

        eq_or_diff(
            $putaway_type,
            $expected->{return},
            "get_putaway_type return value is correct",
        );
        eq_or_diff(
            \$sub_called,
            \$expected->{sub_called},
            "Correct methods were called when not using stored putaway_type",
        );


        note "*** Run: Call get_putaway_type a second time";
        $sub_called = { };
        my $putaway_type_2 = get_putaway_type($self->dbh, $group_id);


        note "*** Test";
        eq_or_diff(
            $putaway_type_2,
            $expected->{return},
            "get_putaway_type return value is correct the second time also",
        );
        if (my $expected_sub_called_stored = $expected->{sub_called_stored}) {
            eq_or_diff(
                $sub_called,
                $expected_sub_called_stored,
                "Correct methods were called when using stored putaway_type",
            );
        }
    }
}

