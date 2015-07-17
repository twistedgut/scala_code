#!/usr/bin/env perl
# invoice.t
# initially introduced to check shipping charges
# but at the time of writing is the only invoice
# test script in place
use NAP::policy "tt", 'test';

use FindBin::libs;


use POSIX qw/floor ceil/;


use Test::More::DBI qw/ dbi_trace /;
use Test::More::Prefix qw/ test_prefix /;

use Test::XTracker::Data;
use Test::XTracker::Mechanize;
use XTracker::Constants::FromDB qw(
    :renumeration_class
    :renumeration_type
    :authorisation_level
    :shipment_item_status
);
use XTracker::Config::Local qw( config_var );
use XTracker::PrintFunctions;
use Test::XT::Flow;
use Test::XTracker::RunCondition database => 'full';

use Data::Dumper;
use URI::file;

# how many records to test
my $TEST_DATA_SIZE = 1;

my $schema = Test::XTracker::Data->get_schema;
my $mech = Test::XTracker::Mechanize->new;



note "* Setup";

my $flow = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Fulfilment',
    ],
);
$flow->mech->force_datalite(1);


my ($channel, $pids) = Test::XTracker::Data->grab_products({ how_many => 1 });
my %product_info = map {( "P$_" => shift( @$pids ) )} 1..(scalar @$pids);



sub list_countries {
    my ($message, $country_rs) = @_;
    note $message;

    while ( my $country_row = $country_rs->next ) {
        note 'Country:' . $country_row->country;
    }
    note 'Count:' . $country_rs->count;
}

sub search_country__without_tax_rate_rs {
    my ($schema) = @_;
    return $schema->resultset('Public::Country')->search(
        { 'country_tax_rate.country_id' => { '=' => undef } },
        {  join => 'country_tax_rate' },
    );
}

sub search_country__with_tax_rate_without_tax_rule_rs {
    my ($schema) = @_;
    return $schema->resultset('Public::Country')->search(
        {
            'country_tax_rate.country_id' => { '!=' => undef },
            'tax_rule_values.country_id'  => { '=' => undef }
        },
        {  join => ['country_tax_rate','tax_rule_values'] }
    );
}

sub search_country__with_tax_rate_with_tax_rule_rs {
    my ($schema) = @_;
    return $schema->resultset('Public::Country')->search(
        {
            'country_tax_rate.country_id' => { '!=' => undef },
            'tax_rule_values.country_id'  => { '!=' => undef },
            'tax_rule.rule'               => { '=' => 'Order Threshold' },
        },
        { join => ['country_tax_rate', {tax_rule_values => 'tax_rule'} ] }
    );
}

sub search_shipment__county_without_tax_rate {
    my ($schema) = @_;
    return $schema->resultset('Public::Shipment')->search(
        {
            'country_tax_rate.country_id'         => { '=' => undef                      } ,
            'renumerations.shipment_id'           => { '!=' => undef                     } ,
            'renumerations.renumeration_class_id' => { '=' => $RENUMERATION_CLASS__ORDER } ,
            'shipping_charge'                     => { '>' => 0                          },
            #'renumerations.store_credit'         => { '=' => 0                          },
            #'renumerations.gift_credit'          => { '=' => 0                          },
        },
        {
            join => [
                'renumerations',
                { shipment_address => { country_table => 'country_tax_rate' } },
            ],
        }
    );
}

sub search_shipment__county_with_tax_rate_without_tax_rule {
    my ($schema) = @_;
    return $schema->resultset('Public::Shipment')->search(
        {
            'country_tax_rate.country_id'         => { '!=' => undef } ,
            'tax_rule_values.country_id'          => { '=' => undef } ,
            'shipping_charge'                     => { '>' => 0 },
            'renumerations.shipment_id'           => { '!=' => undef } ,
            'renumerations.renumeration_class_id' => { '=' => $RENUMERATION_CLASS__ORDER } ,
            #'renumerations.store_credit'         => { '=' => 0 },
            #'renumerations.gift_credit'          => { '=' => 0 },
        },
        {
            join => [
                'renumerations',
                {
                    shipment_address => {
                        country_table => ['country_tax_rate', 'tax_rule_values'],
                    },
                },
            ],
        }
    );
}

sub search_shipment__county_with_tax_rate_with_tax_rule {
    my ($schema) = @_;
    return $schema->resultset('Public::Shipment')->search(
        {
            'country_tax_rate.country_id'         => { '!=' => undef } ,
            'tax_rule_values.country_id'          => { '!=' => undef } ,
            'tax_rule.rule'                       => { '=' => 'Order Threshold' },
            'shipping_charge'                     => { '>' => 0 },
            'renumerations.shipment_id'           => { '!=' => undef } ,
            'renumerations.renumeration_class_id' => { '=' => $RENUMERATION_CLASS__ORDER } ,
            'renumerations.store_credit'          => { '=' => 0 },
            'renumerations.gift_credit'           => { '=' => 0 },
        },
        { join => [ 'renumerations', {shipment_address => { country_table => ['country_tax_rate',{tax_rule_values => 'tax_rule'}] } }  ]  }
    );
}

sub create_shipment_to_country_without_tax_rate {
    my ($schema) = @_;

    ok(
        my $country = search_country__without_tax_rate_rs($schema)->first,
        "Found a country without a tax rate",
    );
    my $country_name = $country->country;
    my $address = Test::XTracker::Data->order_address({
        address => "create",
        country => $country_name,
    });
    my $new_shipment_info = $flow->flow_db__fulfilment__create_order_selected(
        channel              => $channel,
        products             => [ $product_info{"P1"} ],
        address              => $address,
        create_renumerations => 1,
    );

    return $new_shipment_info->{shipment_object};
}

sub create_shipment_to_country_with_tax_rate {
    my ($schema) = @_;

    ok(
        my $country = search_country__with_tax_rate_without_tax_rule_rs($schema)->first,
        "Found a country with a tax rate, but no tax rule",
    );
    my $country_name = $country->country;
    my $address = Test::XTracker::Data->order_address({
        address => "create",
        country => $country_name,
    });
    my $new_shipment_info = $flow->flow_db__fulfilment__create_order_selected(
        channel              => $channel,
        products             => [ $product_info{"P1"} ],
        address              => $address,
        create_renumerations => 1,
    );

    return $new_shipment_info->{shipment_object};
}

sub create_shipment_to_country_with_tax_rate_with_tax_rule {
    my ($schema) = @_;

    ok(
        my $country = search_country__with_tax_rate_with_tax_rule_rs($schema)->first,
        "Found a country with a tax rate, but no tax rule",
    );
    my $country_name = $country->country;
    my $address = Test::XTracker::Data->order_address({
        address => "create",
        country => $country_name,
    });
    my $new_shipment_info = $flow->flow_db__fulfilment__create_order_selected(
        channel              => $channel,
        products             => [ $product_info{"P1"} ],
        address              => $address,
        create_renumerations => 1,
    );

    return $new_shipment_info->{shipment_object};
}


sub test_existing_and_fixture_data {
    my ($test_sub, $existing_shipments_rs, $test_shipment_row) = @_;

    test_prefix("Existing data");
    my $count = 0;
    while (my $shipment = $existing_shipments_rs->next) {
        last if (++$count > $TEST_DATA_SIZE);
        $test_sub->($shipment);
    }


    test_prefix("Test data");
    $test_sub->( $test_shipment_row );
    test_prefix("");

}


####################################################

note("*** first get invoice for country with no tax code");
note("*** grand total should be correct");

{
    my $test_sub = sub {
        my ($shipment) = @_;

        note '############################';
        note 'Country:' . $shipment->shipment_address->country;

        note 'Shipment ID:' . $shipment->id;
        my $renumeration = $shipment->get_sales_invoice;
        note 'Invoice ID:' . $renumeration->id;
        $renumeration->generate_invoice;

        my $path_to_invoice = XTracker::PrintFunctions::path_for_print_document({
            document_type => 'invoice',
            id => $renumeration->id,
            extension => 'html',
        });
        note 'Checking invoice:' . $path_to_invoice;

        ok (-e $path_to_invoice, 'Invoice ' . $path_to_invoice . ' exists' );

        my $uri = URI::file->new($path_to_invoice);
        $mech->get_ok( $uri, 'Fetching ' . $path_to_invoice . ' from disk' );

        my $no_tax_ref = get_values ( $mech );

        note Dumper $no_tax_ref;

        my $local_total = _d2($no_tax_ref->{total_price} + $no_tax_ref->{shipping} + $no_tax_ref->{store_credit} + $no_tax_ref->{gift_credit});

        is ($no_tax_ref->{grand_total}, $local_total, "Grand Total is correct") || die();
    };


    test_existing_and_fixture_data(
        $test_sub,
        scalar search_shipment__county_without_tax_rate($schema),
        scalar create_shipment_to_country_without_tax_rate($schema),
    );
};



####################################################

note("*** get invoice and check Gift Vouchers tenders ");
note("*** are taken into account when calculating the grand total ");
note("*** gift voucher value should be shown ");
note("*** grand total should be correct ");

{
    $schema->txn_do( sub {

        my $test_sub = sub {
            my ($shipment) = @_;

            note '############################';
            note 'Country:' . $shipment->shipment_address->country;

            my $voucher     = Test::XTracker::Data->create_voucher();
            my $vouch_code  = $voucher->create_related( 'codes', { code => 'THISISATEST'.$voucher->id } );
            my $order       = $shipment->order;
            my $tenders     = $order->tenders;
            $tenders->search_related('renumeration_tenders')->delete;
            $tenders->delete;
            $order->create_related(
                'tenders',
                {
                    rank            => 0,
                    value           => 50,
                    voucher_code_id => $vouch_code->id,
                    type_id         => $RENUMERATION_TYPE__VOUCHER_CREDIT,
                },
            );

            note 'Shipment ID:' . $shipment->id;
            my $renumeration = $shipment->get_sales_invoice;
            note 'Invoice ID:' . $renumeration->id;
            $renumeration->update( { gift_voucher => -50 } );
            $renumeration->generate_invoice;

            my $path_to_invoice = XTracker::PrintFunctions::path_for_print_document({
                document_type => 'invoice',
                id => $renumeration->id,
                extension => 'html',
            });
            note 'Checking invoice:' . $path_to_invoice;

            ok (-e $path_to_invoice, 'Invoice ' . $path_to_invoice . ' exists' );

            my $uri = URI::file->new($path_to_invoice);
            $mech->get_ok( $uri, 'Fetching ' . $path_to_invoice . ' from disk' );

            my $gift_vouch = get_values ( $mech );

            #note Dumper $gift_vouch;

            my $local_gift_vouch = _d2( -50 );
            is ($gift_vouch->{gift_voucher}, $local_gift_vouch, "Gift Voucher Total is correct") || die();
            my $local_total = _d2($gift_vouch->{total_price} + $gift_vouch->{shipping} + $gift_vouch->{store_credit} + $gift_vouch->{gift_credit} - 50);
            is ($gift_vouch->{grand_total}, $local_total, "with Gift Voucher Grand Total is correct") || die();
        };



        test_existing_and_fixture_data(
            $test_sub,
            scalar search_shipment__county_without_tax_rate($schema),
            scalar create_shipment_to_country_without_tax_rate($schema),
        );

        $schema->txn_rollback();
    } );
};



####################################################

note("*** next get invoices for country");
note("*** WITH tax code");
note("*** and NO tax rule");
note("*** grand total should be correct and");
note("*** shipping tax should be set");

{
    list_countries(
        "Countries with tax rate BUT NO tax rule",
        scalar search_country__with_tax_rate_without_tax_rule_rs($schema),
    );

    my $test_sub = sub {
        my ($shipment) = @_;

        note 'Country:' . $shipment->shipment_address->country;
        my $country_tax_name = $shipment->shipment_address->country_table->country_tax_rate->tax_name || config_var( 'Tax', 'default_tax_name' );
        note 'Country tax name:' . $country_tax_name;
        note 'Shipment ID:' . $shipment->id;
        my $renumeration = $shipment->get_sales_invoice;
        note 'Invoice ID:' . $renumeration->id;
        $renumeration->generate_invoice;

        my $path_to_invoice = XTracker::PrintFunctions::path_for_print_document({
            document_type => 'invoice',
            id => $renumeration->id,
            extension => 'html',
        });

        ok (-e $path_to_invoice, 'Invoice ' . $path_to_invoice . ' exists' );

        my $uri = URI::file->new($path_to_invoice);
        $mech->get_ok( $uri, 'Fetching ' . $path_to_invoice . ' from disk' );

        my $with_tax_ref = get_values ( $mech, $country_tax_name );

        note Dumper $with_tax_ref;

        my $local_total = _d2($with_tax_ref->{total_price} + $with_tax_ref->{shipping} + $with_tax_ref->{shipping_tax} + $with_tax_ref->{store_credit} + $with_tax_ref->{gift_credit});

        is ($with_tax_ref->{grand_total}, $local_total, "Grand Total is correct") || die();
        ok ($with_tax_ref->{shipping_tax} > 0,  "Shipping tax is > 0");
    };


    test_existing_and_fixture_data(
        $test_sub,
        scalar search_shipment__county_with_tax_rate_without_tax_rule($schema),
        scalar create_shipment_to_country_with_tax_rate($schema),
    );
};


####################################################

note("*** next get invoices for country");
note("*** WITH tax code");
note("*** AND tax rule");
note("*** and amount below threshold");
note("*** grand total should be correct and");
note("*** shipping tax should be set");

{
    list_countries(
        "Countries with tax rate AND tax rule",
        scalar search_country__with_tax_rate_with_tax_rule_rs($schema),
    );

    my $test_sub = sub {
        my ($shipment) = @_;

        note 'Country:' . $shipment->shipment_address->country;
        my $country_tax_name = $shipment->shipment_address->country_table->country_tax_rate->tax_name || 'VAT';
        note 'Country tax name:' . $country_tax_name;
        my $threshold = _d2($shipment->shipment_address->country_table->tax_rule_values->single->value);
        note 'Threshold:' . $threshold;
        note 'Shipment ID:' . $shipment->id;
        my $renumeration = $shipment->get_sales_invoice;
        note 'Invoice ID:' . $renumeration->id;
        $renumeration->generate_invoice;

        my $path_to_invoice = XTracker::PrintFunctions::path_for_print_document({
            document_type => 'invoice',
            id => $renumeration->id,
            extension => 'html',
        });

        ok (-e $path_to_invoice, 'Invoice ' . $path_to_invoice . ' exists' );

        my $uri = URI::file->new($path_to_invoice);
        $mech->get_ok( $uri, 'Fetching ' . $path_to_invoice . ' from disk' );

        my $threshold_tax_ref = get_values ( $mech, $country_tax_name );

        note Dumper $threshold_tax_ref;

        my $local_total = _d2( $threshold_tax_ref->{total_price} + $threshold_tax_ref->{shipping} + $threshold_tax_ref->{shipping_tax} + $threshold_tax_ref->{gift_credit} + $threshold_tax_ref->{store_credit});

        is ($threshold_tax_ref->{grand_total}, $local_total, "Grand Total is correct") || die();

        if ($local_total > $threshold) {
            ok ($threshold_tax_ref->{shipping_tax} > 0,  "Shipping tax is > 0");
        } else {
            ok ($threshold_tax_ref->{shipping_tax} == 0,  "Shipping tax is 0");
        }
    };


    test_existing_and_fixture_data(
        $test_sub,
        scalar search_shipment__county_with_tax_rate_with_tax_rule($schema),
        scalar create_shipment_to_country_with_tax_rate_with_tax_rule($schema),
    );
};


######################

done_testing;

sub get_values {
    my $mech = shift;
    my $country_tax_name = shift;

    my @total_price  = $mech->get_table_row('TOTAL PRICE');
    my @shipping     = $mech->get_table_row('SHIPPING'   );
    my @grand_total  = $mech->get_table_row('GRAND TOTAL');
    my @store_credit = $mech->get_table_row('STORE CREDIT');
    my @gift_voucher = $mech->get_table_row('GIFT VOUCHER');
    my @gift_credit  = $mech->get_table_row('GIFT CERTIFICATE CREDIT');
    my @shipping_tax;
    if ($country_tax_name) {
        @shipping_tax = $mech->get_table_row('SHIPPING ' . $country_tax_name);
    }

    my $cash_regex = '([^\s]).*?(-?\d*\.\d{2})';

    # find the column index with the values in
    my( $found, $index ) = ( undef, -1 );
    for my $i (0 .. $#total_price) {
        if( $total_price[$i] =~ /$cash_regex/o ) {
            $found = $total_price[$i];
            $index = $i;
            last;
        }
    }

    # as some values may be missing for valid reasons - this is not the test
    no warnings; ## no critic(ProhibitNoWarnings)

    my ($total_price)  = ( $total_price[$index]  =~  /$cash_regex/)[1];  # [0] should be currecny symbol
    my ($shipping)     = ( $shipping[$index]     =~  /$cash_regex/)[1];
    my ($shipping_tax) = ( $shipping_tax[$index] =~  /$cash_regex/)[1];
    my ($grand_total)  = ( $grand_total[$index]  =~  /$cash_regex/)[1];
    my ($store_credit) = ( $store_credit[$index] =~  /$cash_regex/)[1];
    my ($gift_credit)  = ( $gift_credit[$index]  =~  /$cash_regex/)[1];
    my ($gift_voucher) = ( $gift_voucher[$index] =~  /$cash_regex/)[1];

    #print join ':', ($total_price, $shipping, $shipping_tax, $grand_total);

    return {
        total_price  => _d2($total_price  ), #* 100,
        shipping     => _d2($shipping     ), #* 100,
        shipping_tax => _d2($shipping_tax ), #* 100,
        grand_total  => _d2($grand_total  ), #* 100,
        store_credit => _d2($store_credit ), #* 100,
        gift_credit  => _d2($gift_credit  ), #* 100,
        gift_voucher => _d2($gift_voucher ), #* 100,
    };
}

sub _intify {
    my $num = shift;
    my $float = sprintf('%.4f', $num);
    my $int = sprintf('%d', $float);
    return $int;
}

sub _d2 {
    my $num = shift || 0;
    my $d2 = sprintf('%0.2f', $num);
    return $d2;
}



