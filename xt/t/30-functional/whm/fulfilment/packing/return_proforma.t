#!/usr/bin/env perl

=head1 NAME

return_proforma.t - Test the return proforma

=head1 DESCRIPTION

Tests the return proforma, in terms of checking that Euros are displayed
when the order currency is in Euros, unless the DC is DC2

Generate Orders for each of the currencies available to the DC. Tax and Duty
should be ignored in the Proforma. Then create a Gift Order, use an alternative
currency rather than the local, one if there is one.

Add in what the above currency should be converted to and how many currencies
will be shown on the Returns Proforma for each Order.

Verify the following things:

    * Document title is correct
    * Qantity of Shipment Items doesn't incude any Cancelled Items
    * Number of currencies shown on page is as expected

    Check the values for each currency:
    * Unit Value for $currency as expected
    * Subtotal for $currency as expected
    * Total for $currency as expected

    Or for a Gift Shipment:
    * Unit Value for $currency is blank
    * Subtotal for $currency is blank
    * Total for $currency is blank

    * Check the Currency is shown as expected

#TAGS fulfilment packing checkruncondition loops finance printer whm

=cut

use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::RunCondition export => [ qw( $distribution_centre ) ];


use Test::XTracker::Data;
use Test::XTracker::PrintDocs;

use XTracker::Constants::FromDB   qw(
    :shipment_item_status
    :shipment_status
    :shipment_type
);

use XTracker::Config::Local qw( config_var );
use XTracker::Database::Shipment qw( check_tax_included );
use XTracker::Database::Currency qw( get_currency_id get_currencies_from_config );

# make DB connections
my $schema  = Test::XTracker::Data->get_schema;
my $dbh     = $schema->storage->dbh;
isa_ok($schema, 'XTracker::Schema',"Schema Created");
isa_ok($dbh, 'DBI::db',"DBH Created");

my $resultset   = _define_dbic_resultset( $schema );

my $dc_name     = Test::XTracker::Data->whatami();
my $retpro_ctry = $resultset->{retpro_country}();

my $print_directory = Test::XTracker::PrintDocs->new();

# get all DC Currencies then get the Local Currency & Alternatives
my $dc_currencies = get_currencies_from_config( $schema );
my ( $local_currency, @alt_currency ) = @{ $dc_currencies };      # Local is always the first one

# generate Orders for each of the
# Currencies available to the DC
# Tax & Duty should be ignored in the Proforma
my %create_orders = map {
    $_->{name} . ' Currency' => {
        country     => $retpro_ctry,
        normal_pid  => 1,
        currency    => $_->{name},
        item_tax    => 5,
        item_duty   => 8,
    }
} @{ $dc_currencies };

# then create a Gift Order, use an Alternative
# Currency rather than the Local one if there is one
$create_orders{ 'Gift ' . $dc_currencies->[-1]{name} .' Shipment' } = {
    country     => $retpro_ctry,
    normal_pid  => 1,
    currency    => $dc_currencies->[-1]{name},
    item_tax    => 5,
    item_duty   => 8,
    gift_shipment => 1,
};

# add in what the above currency should be converted to and how many
# currencies will be shown on the Returns Proforma for each Order
foreach my $args ( values %create_orders ) {
    $args->{currencies_shown}   = [ $local_currency->{name} ];
    # if the Currency for the Order is NOT the Local Currency
    if ( $args->{currency} ne $local_currency->{name} ) {
        $args->{converted_to}   = $local_currency->{name};
        # if there are Alternative Currencies for the DC then
        # both Currencies will be displayed on the Proforma
        if ( @alt_currency ) {
            $args->{currencies_shown}->[1]  = $args->{currency};
        }
    }
}

note "TEST Return Proforma";

foreach my $tmethod ( sort keys %create_orders ) {

    note "Testing with: ".$tmethod;

    my $targs   = $create_orders{ $tmethod };
    my $order   = _create_an_order( $targs );
    my $shipment= $order->shipments->first;

    my $expect_tax  = check_tax_included( $dbh, $shipment->shipment_address->country );

    note "Checking with Country: ".$targs->{country}.", Currency: ".$targs->{currency}.", Order Id: ".$order->id.", Shipment Id: ".$shipment->id;

    my %values;
    my %totals;

    my $conv_unit_value = 0;
    my $unit_value      = 100;
    if ( $targs->{converted_to} ) {
        # get conversion rate
        my $from_curr   = $schema->resultset('Public::Currency')->find( $targs->{currency}, { key => 'currency_currency_key' } );
        my $exch_rate   = $from_curr->conversion_rate_to( $targs->{converted_to} );

        note "Using Exchange rate from ".$targs->{currency}." to ".$targs->{converted_to}.": ".$exch_rate;
        # convert the values
        $conv_unit_value    = sprintf( "%.2f", $unit_value * $exch_rate );

        $values{$targs->{converted_to}} = $conv_unit_value;
        $totals{$targs->{converted_to}} = $conv_unit_value;
    }
    $values{$targs->{currency}} = $unit_value;
    $totals{$targs->{currency}} = $unit_value;

    note "Generate Return Proforma";
    $shipment->generate_return_proforma( { printer => 'Shipping', copies => 1 } );
    my ($doc)   = map { $_->as_data } grep { $_->file_type eq 'retpro' } $print_directory->new_files;

    is( $doc->{document_title}, 'RETURNS PROFORMA INVOICE/COMMERCIAL INVOICE', "Document Title is Correct" );

    my $item        = $doc->{shipment_items}{items}[0];
    my $item_totals = $doc->{shipment_items}{totals};
    cmp_ok( $item->{qty}, '==', $shipment->non_cancelled_items->count,
                                    "Qty of Shipment Items doesn't incude any Cancelled Items" );

    # check the number of currencies shown
    my $currencies      = lc( join( "\|", @{ $targs->{currencies_shown} } ) );
    my $currency_check  = qr/($currencies)_unit_value/;
    my $currencies_shown = scalar( grep { $_ =~ $currency_check } keys %{ $item } );
    cmp_ok( $currencies_shown, '==', scalar( @{ $targs->{currencies_shown} } ), "Number of Currencies Show on Page as Expected: ".@{ $targs->{currencies_shown} } );

    # check the values for each currency
    foreach my $currency ( @{ $targs->{currencies_shown} } ) {
        my $curr_prefix = lc( $currency );
        if ( !$shipment->gift ) {
            cmp_ok( $item->{$curr_prefix."_unit_value"}, '==', $values{$currency},
                                                "Unit Value for $currency as expected: ".$values{$currency} );
            cmp_ok( $item->{$curr_prefix."_subtotal"}, '==', $values{$currency},
                                                "Subtotal for $currency as expected: ".$values{$currency} );
            cmp_ok( $item_totals->{$curr_prefix."_total"}, '==', $totals{$currency},
                                                "Total for $currency as expected: ".$totals{$currency} );
        }
        else {
            is( $item->{$curr_prefix."_unit_value"}, "",
                                                "Gift Shipment: Unit Value for $currency is BLANK" );
            is( $item->{$curr_prefix."_subtotal"}, "",
                                                "Gift Shipment: Subtotal for $currency is BLANK" );
            is( $item->{$curr_prefix."_total"}, undef,
                                                "Gift Shipment: Total for $currency is BLANK" );
        }
    }

    # check the Currency is shown as expected
    my $currency_desc   = config_var('Currency', 'local_currency_code');
    like( $doc->{currency}, qr/$currency_desc/, "Currency is $currency_desc" );
}

done_testing();

#--------------------------------------------------------------

# creates an order
sub _create_an_order {
    my $args    = shift;

    my $item_tax    = $args->{item_tax} || 50;
    my $item_duty   = $args->{item_duty} || 0;

    note "Creating Order";

    my ( $channel, $pids )  = Test::XTracker::Data->grab_products;
    my @pids_to_use;
    push @pids_to_use, $pids->[0];

    my $currency        = $args->{currency} || config_var('Currency', 'local_currency_code');

    my $currency_id     = get_currency_id( Test::XTracker::Data->get_schema->storage->dbh, $currency );
    my $carrier_name    = ( $channel->is_on_dc( 'DC2' ) ? 'UPS' : config_var('DistributionCentre','default_carrier') );
    my $ship_account    = Test::XTracker::Data->find_shipping_account( { carrier => $carrier_name, channel_id => $channel->id } );

    my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

    Test::XTracker::Data->ensure_stock( $pids->[0]{pid}, $pids->[0]{size_id}, $channel->id );

    my $base = {
        customer_id => $customer->id,
        currency_id => $currency_id,
        channel_id  => $channel->id,
        shipment_type => $SHIPMENT_TYPE__INTERNATIONAL,
        shipment_status => $SHIPMENT_STATUS__PROCESSING,
        shipment_item_status => $SHIPMENT_ITEM_STATUS__NEW,
        shipping_account_id => $ship_account->id,
        invoice_address_id => Test::XTracker::Data->create_order_address_in('current_dc_premier')->id,
        gift_shipment => ( exists( $args->{gift_shipment} ) ? $args->{gift_shipment} : 0 ),
    };


    my($order,$order_hash) = Test::XTracker::Data->create_db_order({
        pids => \@pids_to_use,
        base => $base,
        attrs => [
            { price => 100.00, tax => $item_tax, duty => $item_duty },
        ],
    });

    my $shipment = $order->shipments->first;
    my $shipment_item = $shipment->shipment_items->first;

    # Create an identical shipment item but cancelled,
    # to make sure only non cancelled items are included
    # in the pro-forma.
    $shipment->create_related( 'shipment_items', {
        variant_id              => $shipment_item->variant_id,
        unit_price              => $shipment_item->unit_price,
        tax                     => $shipment_item->tax,
        duty                    => $shipment_item->duty,
        shipment_item_status_id => $SHIPMENT_ITEM_STATUS__CANCELLED,
        special_order_flag      => $shipment_item->special_order_flag,
        shipment_box_id         => $shipment_item->shipment_box_id,
        returnable_state_id     => $shipment_item->returnable_state_id,
    } );

    $shipment->shipment_items->update( { tax => $item_tax } );

    return $order;

}

# defines a set of commands to be used by a DBiC connection
sub _define_dbic_resultset {
    my $schema      = shift;

    my $resultset   = {};

    $resultset->{retpro_country}= sub {
            # don't want US or UK
            my @exclude_countries  = (
                    "United Kingdom",
                    "United States",
                    "Hong Kong",
                );

            my $rs  = $schema->resultset('Public::Country');
            return $rs->search( { country => { -not_in => \@exclude_countries }, proforma => { '>' => 0 }, returns_proforma => { '>' => 0 } } )
                                        ->first->country;
        };

    return $resultset;
}
