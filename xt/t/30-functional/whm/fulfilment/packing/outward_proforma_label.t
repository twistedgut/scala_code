#!/usr/bin/env perl

=head1 NAME

outward_proforma_label.t

=head1 DESCRIPTION

Generate orders for different countries and then generate the outward proforma.

The contents of the proforma are analysed to determine that the contents of the
forms are as expected.

=cut

use NAP::policy 'test';

use FindBin::libs;

use Test::XT::Prove::Feature::DHL;
use Test::XTracker::Data;
use Test::XTracker::Data::Country;
use Test::XTracker::PrintDocs;
use Test::XTracker::Artifacts::Labels;

use XTracker::Config::Local qw(dhl_xmlpi config_var);
use XTracker::Constants::FromDB qw{
    :shipment_item_status
    :shipment_status
    :shipment_type
    :sub_region
};
use XTracker::Database::Shipment 'check_tax_included';
use XTracker::Order::Printing::OutwardProforma 'generate_outward_proforma';
use Test::XTracker::Data::MarketingPromotion;

# This tests in particular the outward proforma, in terms
# of checking currency conversions aren't taking place and
# Norway is treated differently
my $schema  = Test::XTracker::Data->get_schema;
my $dbh     = $schema->storage->dbh;
my $xmlpi_info = dhl_xmlpi();
my $region_code = $xmlpi_info->{region_code};

my $domestic_address = $region_code eq 'EU' ? 'LondonPremier' : (
                       $region_code eq 'AM' ? 'ManhattanPremier' : (
                       $region_code eq 'AP' ? 'HongKongPremier' :
                                              die "The region code provided($region_code) is unknown." ) );

# stuff used to create orders.
# Tax & Duty should be ignored in the Outward Proforma
# Note: the addresses for the following orders are configured in
# Test::Role::Address
my %create_orders = (
    # Domestic non-voucher shipment
    'Domestic parcel' => {
        address_location     => $domestic_address,
        title                => 'PROFORMA INVOICE',
        currency             => 'EUR',
        is_domestic          => 1,
    },
    # Domestic voucher only shipment
    'Domestic document' => {
        address_location     => $domestic_address,
        title                => 'PROFORMA INVOICE',
        currency             => 'EUR',
        is_domestic          => 1,
    },
    # CANDO-1493: Test weighted and unweighted promotions
    'With a Weightless Marketing Promotion' => {
        address_location     => 'Russia',
        normal_pid           => 1,
        title                => 'PROFORMA INVOICE',
        currency             => 'GBP',
        item_tax             => 5,
        item_duty            => 8,
        marketing_promotion => {
            weighted => 0,
        },
    },
    'With a Weighted Marketing Promotion' => {
        address_location     => 'Russia',
        normal_pid           => 1,
        title                => 'PROFORMA INVOICE',
        currency             => 'GBP',
        item_tax             => 5,
        item_duty            => 8,
        marketing_promotion => {
            weighted => 1,
        },
    },

);

my $channel = Test::XTracker::Data->channel_for_nap;

foreach my $tname ( sort keys %create_orders ) {
    my $targs   = $create_orders{ $tname };

    my $order   = _create_an_order( $targs );
    my $shipment= $order->shipments->first;

    my $subtest_name = join q{, },
        $tname,
        "(address = $targs->{address_location}",
        "currency = $targs->{currency}",
        'order_id = ' . $order->id,
        'shipment id = ' . $shipment->id . ")";

    my $print_directory = Test::XTracker::PrintDocs->new(filter_regex => qr{\.(?:html|lbl)$});
    subtest "$subtest_name: test outward proforma" => sub {
        # Not quite sure where these come from
        my $unit_value = $targs->{vouchers_only}
                         ? 1
                         : 100;
        my $ship_value = 10;
        my $total      = $unit_value + $ship_value;

        generate_outward_proforma( $dbh, $shipment->id, 'Shipping', 1, $schema );
        my ($doc) = map { $_->as_data } grep { $_->file_type eq 'outpro' } $print_directory->new_files;

        is( $doc->{document_title}, $targs->{title}, "Document Title is: ".$targs->{title} );

        my $shipping_index = 1;

        if ( exists $targs->{marketing_promotion} && $targs->{marketing_promotion}{weighted} == 1 ) {

            $total++;
            $shipping_index++;
            is( @{ $doc->{shipment_items}{items} }, 3, 'There are three rows when a weighted promotion is present' );

            my $promotion_row = $doc->{shipment_items}{items}[1];
            cmp_ok( $promotion_row->{value}, '==', '1.00', "Promotion unit Value is 1.00" );
            cmp_ok( $promotion_row->{subtotal}, '==', '1.00', "Promotion unit Sub Total is 1.00" );


        } else {

            is( @{ $doc->{shipment_items}{items} }, 2, 'There are two rows when no weighted promotion is present' );

        }


        # check Values have not been Converted.
        # check first row should be the product
        # second row should be shipping
        my $product_row = $doc->{shipment_items}{items}[0];
        my $shipping_row = $doc->{shipment_items}{items}[ $shipping_index ];
        cmp_ok( $product_row->{value}, '==', $unit_value, "Unit Value is $unit_value" );
        cmp_ok( $product_row->{subtotal}, '==', $unit_value, "Unit Sub Total is $unit_value" );
        cmp_ok( $shipping_row->{value}, '==', $ship_value, "Shipping Value is $ship_value" );
        cmp_ok( $shipping_row->{subtotal}, '==', $ship_value, "Shipping Sub Total is $ship_value" );

        # check total value
        cmp_ok( $doc->{shipment_items}{total}, '==', $total, "Total Value is $total" );

        # check the Currency is shown as expected
        like( $doc->{footer}, qr/ALL CURRENCY IN $targs->{currency}/, "Currency is $targs->{currency}" );
    };
}

done_testing;

sub _create_an_order {
    my $args    = shift;

    note "Get pids";
    my %voucher_options;
    $args->{vouchers_only} and %voucher_options = (
        how_many => 0,
        phys_vouchers   => {
            how_many                 => 1,
            want_stock               => 1,
            value                    => '100.00',
            assign_code_to_ship_item => 1,
        },
    );

    my $pids = (Test::XTracker::Data->grab_products({
        channel_id => $channel->id,
        %voucher_options,
    }))[1];

    note "Ensure stock";
    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my @voucher_pids = grep { $_->{voucher} } @$pids;
    if($args->{vouchers_only}) {
        $pids = [ @voucher_pids ];
    }

    my $currency = $schema->resultset('Public::Currency')->find({
        currency => $args->{currency} || config_var(qw/Currency local_currency_code/)
    });
    my $carrier_name = config_var(qw/DistributionCentre default_carrier/);

    my $ship_account = Test::XTracker::Data->find_shipping_account({
        carrier    => $carrier_name,
        channel_id => $channel->id,
    });
    my $address = Test::XTracker::Data->create_order_address_in( $args->{address_location} );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $shipment_type = $args->{is_domestic}
                      ? $SHIPMENT_TYPE__DOMESTIC
                      : $SHIPMENT_TYPE__INTERNATIONAL;

    my $base = {
        customer_id          => $customer->id,
        currency_id          => $currency->id,
        channel_id           => $channel->id,
        shipment_type        => $shipment_type,
        shipment_status      => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id  => $ship_account->id,
        invoice_address_id   => $address->id,
    };
    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => $pids,
        base => $base,
    });

    if ( exists $args->{marketing_promotion} ) {

        # Clear out any unwanted promotions.
        Test::XTracker::Data::MarketingPromotion
            ->delete_all_promotions_by_channel( $channel->id );

        # Create a marketing promotion.
        my $promotions = Test::XTracker::Data::MarketingPromotion
            ->create_marketing_promotion( {
                channel_id  => $channel->id,
                count       => 1,
                $args->{marketing_promotion}{weighted}
                    ? (
                        promotion_type => {
                            # The name needs to be unique.
                            name    => 'Marketing Promotion for Order ID ' . $order->id,
                            # We explicitly specify the weight, so we know what to expect.
                            weight  => 0.5
                        }
                    )
                    : (),
            } );

        # Link the promotion to the order.
        Test::XTracker::Data::MarketingPromotion
            ->create_link( $order, $promotions->[0] );

    }

    return $order;
}
