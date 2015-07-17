#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;
use DateTime;

use Test::XTracker::Data;
use Test::XTracker::RunCondition export => ['$distribution_centre'];
use Test::XTracker::ParamCheck;

use XTracker::Config::Local     qw( config_var );
use XTracker::Constants         qw( $APPLICATION_OPERATOR_ID );
use XTracker::Constants::FromDB qw( :currency :country :region :sub_region );

use DateTime;
use Math::Round;
use Data::Dump  qw( pp );
use List::Util 'sum';


use Test::Exception;

BEGIN {
    use_ok('XTracker::Database', qw( :common ));
    use_ok('XTracker::Database::Pricing', qw(
                            get_product_selling_price
                        ) );

    can_ok("XTracker::Database::Pricing", qw(
                            get_product_selling_price
                        ) );
}

my $schema  = Test::XTracker::Data->get_schema();
my $dbh     = $schema->storage->dbh;

#---- Test Functions ------------------------------------------

_test_pricing_funcs($dbh,$schema,1);

#--------------------------------------------------------------

done_testing();

#---- TEST FUNCTIONS ------------------------------------------

# This tests pricing functions
sub _test_pricing_funcs {

    my $dbh     = shift;
    my $schema  = shift;

    my $tmp;
    my @tmp;

    SKIP: {
        skip "_test_pricing_funcs"          if (!shift);

        note "TESTING Pricing Functions";

        my $local_currency  = $schema->resultset('Public::Currency')
                                        ->search( { currency => config_var( 'Currency', 'local_currency_code' ) } )
                                            ->first;
        my $alt_currency    = $schema->resultset('Public::Currency')
                                        ->search( {
                                                    currency => { '!=' => config_var( 'Currency', 'local_currency_code' ) },
                                                    # don't use Unknown or Australian Dollars as this isn't real world
                                                    id => { 'NOT IN' => [ $CURRENCY__UNK, $CURRENCY__AUD ] },
                                                } )
                                            ->first;

        note "Using Local Currency: ".$local_currency->currency;
        note "Using Alt. Currency : ".$alt_currency->currency;

        $schema->txn_do( sub {
            # get products
            my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
                                                                channel => 'nap',
                                                                how_many => 1,
                                                                no_markdown => 1,
                                                                phys_vouchers   => {
                                                                    how_many => 1,
                                                                    value => '110.00',
                                                                    currency_id => $local_currency->id,
                                                                },
                                                                virt_vouchers   => {
                                                                    how_many => 1,
                                                                    value => '150.00',
                                                                    currency_id => $local_currency->id,
                                                                },
                                                        } );
            # get the relevant products out of the ARRAY
            isa_ok( my $prod_chan = $pids->[0]{product_channel}, 'XTracker::Schema::Result::Public::ProductChannel' );
            isa_ok( my $product = $pids->[0]{product}, 'XTracker::Schema::Result::Public::Product' );
            isa_ok( my $pvouch = $pids->[1]{product}, 'XTracker::Schema::Result::Voucher::Product' );
            isa_ok( my $vvouch = $pids->[2]{product}, 'XTracker::Schema::Result::Voucher::Product' );

            my $customer    = Test::XTracker::Data->find_customer( { channel_id => $channel->id } );

            note "using Product Id: ".$product->id;

            note "TESTING 'get_product_selling_price'";
            my %price_args  = (
                    county              => '',
                    country             => 'United Kingdom',
                    order_currency_id   => $local_currency->id,
                    customer_id         => $customer->id,
                    order_total         => 510,
                );
            my @retvals;

            note "using Normal Product";
            my $ctry_price  = $schema->resultset('Public::PriceCountry')->search( { product_id => $product->id, country_id => $COUNTRY__UNITED_KINGDOM } );
            $ctry_price->delete;
            my $rgn_price   = $schema->resultset('Public::PriceRegion')->search( { product_id => $product->id, region_id => $REGION__EUROPE } );
            $rgn_price->delete;
            my $def_price   = $schema->resultset('Public::PriceDefault')->find( { product_id => $product->id } );
            $def_price->update( { price => 145, currency_id => $local_currency->id } );
            # get rid of any markdowns, by making them all ZERO %
            $product->search_related('price_adjustments')->update( { percentage => 0 } );

            $price_args{product_id} = $product->id;
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            cmp_ok( @retvals, '==', 3, "Normal Product: got an array with 3 elements" );
            cmp_ok( $retvals[0], '==', 145, "Normal Product: Price is 145" );

            # change the order currency to get a conversion
            _set_season_conv_rate( $dbh, {
                                        season_id   => $product->season_id,
                                        source_cur_id=> $local_currency->id,
                                        dest_cur_id => $alt_currency->id,
                                        rate        => 2,
                                    } );
            $price_args{order_currency_id}  = $alt_currency->id;
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            cmp_ok( $retvals[0], '==', ( 145 * 2 ), "Normal Product: Price is 290 after currency conversion" );

            note "country override";
            $price_args{order_currency_id}  = $CURRENCY__GBP;
            $ctry_price->create({
                currency_id => $price_args{order_currency_id},
                price => 137,
            });
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            if ($distribution_centre ne 'DC2') {
                cmp_ok( sum(@retvals), '==', 137, "Normal Product: gross price is 137 after country override" );
            }
            else {
                cmp_ok( $retvals[0], '==', 137, "Normal Product: net price is 137 after country override" );
            }
            $rgn_price->create({
                region_id => $REGION__EUROPE,
                currency_id => $CURRENCY__EUR,
                price => 375,
            });
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            if ($distribution_centre ne 'DC2') {
                cmp_ok( sum(@retvals), '==', 137, "Normal Product: gross price is 137 after country & region override (uk is not considered in europe)" );
            }
            else {
                cmp_ok( $retvals[0], '==', 137, "Normal Product: net price is 137 after country & region override (uk is not considered in europe)" );
            }
            _set_season_conv_rate( $dbh, {
                                        season_id   => $product->season_id,
                                        source_cur_id=> $CURRENCY__EUR,
                                        dest_cur_id => $CURRENCY__GBP,
                                        rate        => 2,
                                    } );
            { local $price_args{country} = 'France';
              @retvals    = get_product_selling_price( $dbh, \%price_args );
              if ($distribution_centre ne 'DC2') {
                  cmp_ok( sum(@retvals), '==', 750, "Normal Product: gross price is 375 after region override" );
              }
              else {
                  cmp_ok( $retvals[0], '==', 750, "Normal Product: net price is 375 after region override" );
              }
            }

            note "using Physical Voucher Product";
            $price_args{product_id}         = $pvouch->id;
            $price_args{order_currency_id}  = $local_currency->id;
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            cmp_ok( @retvals, '==', 3, "Physical Voucher Product: got an array with 3 elements" );
            cmp_ok( $retvals[0], '==', 110, "Physical Voucher Product: price is 110" );
            cmp_ok( $retvals[1], '==', 0, "Physical Voucher Product: tax is ZERO" );
            cmp_ok( $retvals[2], '==', 0, "Physical Voucher Product: duty is ZERO" );

            # change the order currency to get a conversion
            _set_season_conv_rate( $dbh, {
                                        season_id   => $pvouch->season->id,
                                        source_cur_id=> $local_currency->id,
                                        dest_cur_id => $alt_currency->id,
                                        rate        => 2,
                                    } );
            $price_args{order_currency_id}  = $alt_currency->id;
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            cmp_ok( $retvals[0], '==', ( 110 * 2 ), "Physical Voucher Product: Price is 220 after currency conversion" );

            note "using Virtual Voucher Product";
            $price_args{product_id}         = $vvouch->id;
            $price_args{order_currency_id}  = $local_currency->id;
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            cmp_ok( @retvals, '==', 3, "Virtual Voucher Product: got an array with 3 elements" );
            cmp_ok( $retvals[0], '==', 150, "Virtual Voucher Product: price is 150" );
            cmp_ok( $retvals[1], '==', 0, "Virtual Voucher Product: tax is ZERO" );
            cmp_ok( $retvals[2], '==', 0, "Virtual Voucher Product: duty is ZERO" );

            # change the order currency to get a conversion
            _set_season_conv_rate( $dbh, {
                                        season_id   => $pvouch->season->id,
                                        source_cur_id=> $local_currency->id,
                                        dest_cur_id => $alt_currency->id,
                                        rate        => 2,
                                    } );
            $price_args{order_currency_id}  = $alt_currency->id;
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            cmp_ok( $retvals[0], '==', ( 150 * 2 ), "Virtual Voucher Product: Price is 300 after currency conversion" );

            # using an invalid product id
            note "using an Invalid Product Id";
            $price_args{product_id} = -23443;
            @retvals    = get_product_selling_price( $dbh, \%price_args );
            is_deeply( \@retvals, [0,0,0], "Invalid Product Id returns ALL ZEROES" );

            note "using 'Custom Modifier' tax rule (Brazil)";

            # make sure there's nothing in region/country prices that'll match with Brazil
            my $brazil_ctry_price  = $schema->resultset('Public::PriceCountry')->search( { product_id => $product->id, country_id => $COUNTRY__BRAZIL } );
            $brazil_ctry_price->delete;
            my $brazil_rgn_price   = $schema->resultset('Public::PriceRegion')->search( { product_id => $product->id, region_id => $REGION__AMERICAS } );
            $brazil_rgn_price->delete;

            # set-up the Tax Rules for Brazil
            my $country = $schema->resultset('Public::Country')->search( { country => 'Brazil' } )->first;
            $country->tax_rule_values->delete;      # delete any existing rules & values
            $country->country_tax_rate->delete      if ( defined $country->country_tax_rate );
            $country->country_duty_rates->delete;
            $country->create_related( 'tax_rule_values', {
                                                    tax_rule => {
                                                        rule    => 'Custom Modifier',
                                                    },
                                                    value => 82,
                                                } );
            $country->create_related( 'country_tax_rate', {
                                                    rate => 0.18,
                                                } );
            $country->create_related( 'country_duty_rates', {
                                                    hs_code_id => $product->hs_code_id,
                                                    rate => 0.600,
                                                } );

            $price_args{product_id}         = $product->id;
            $price_args{order_currency_id}  = $local_currency->id; # $CURRENCY__BRL (doesn't exist in db)
            $price_args{country}            = 'Brazil';

            @retvals = get_product_selling_price( $dbh, \%price_args );

            cmp_ok( @retvals, '==', 3, "Custom Modifier: got an array with 3 elements" );
            cmp_ok( $retvals[0], '==', 145, "Custom Modifier: price is 145" );
            cmp_ok( $retvals[1], '==', 4176 / 82, "Custom Modifier: tax is 50.93" );
            cmp_ok( $retvals[2], '==', 87, "Custom Modifier: duty is 87" );

            # undo any changes
            $schema->txn_rollback();
        } );

    }
}

#--------------------------------------------------------------

# create/update a season conversion rate
sub _set_season_conv_rate {
    my ( $dbh, $args )  = @_;

    my $qry =<<SQL
SELECT  id
FROM    season_conversion_rate
WHERE   season_id = ?
AND     source_currency_id = ?
AND     destination_currency_id = ?
SQL
;
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $args->{season_id}, $args->{source_cur_id}, $args->{dest_cur_id} );
    my ( $conv_id ) = $sth->fetchrow_array();

    # if got an id then update else create
    my @args;
    if ( $conv_id ) {
        $qry    =<<SQL
UPDATE season_conversion_rate
    SET conversion_rate = ?
WHERE   id = ?
SQL
;
        @args   = ( $args->{rate}, $conv_id );
    }
    else {
        $qry    =<<SQL
INSERT INTO season_conversion_rate (season_id, source_currency_id, destination_currency_id, conversion_rate )
VALUES (
?,
?,
?,
?
)
SQL
;
        @args   = ( $args->{season_id}, $args->{source_cur_id}, $args->{dest_cur_id}, $args->{rate} );
    }

    $sth    = $dbh->prepare( $qry );
    $sth->execute( @args );
}

