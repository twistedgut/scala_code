#!/usr/bin/env perl
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use NAP::policy "tt", 'test';
use FindBin::libs;
use Test::XTracker::Data;
use XTracker::Config::Local     qw( config_var );
use XTracker::Constants::FromDB qw( :currency :country :region :sub_region );
use DateTime;
use Test::XTracker::RunCondition
    export => [qw( $distribution_centre )];
use XTracker::Database::PricingService;
use XTracker::Database::Pricing 'get_product_selling_price';
use Time::HiRes qw(gettimeofday tv_interval);
use List::AllUtils 'first';

my $schema = Test::XTracker::Data->get_schema();
my $dbh = $schema->storage->dbh;

my %args = (
    schema => $schema,
    default_currency_id => $CURRENCY__GBP,
    default_price => 100,
    country_prices => {
        $COUNTRY__FRANCE => { price => 120, currency_id => $CURRENCY__EUR },
    },
    region_prices => {
        $REGION__EUROPE => { price => 150, currency_id => $CURRENCY__EUR },
    },
    currency_conversion_rates => {
        $CURRENCY__USD => { # helps in DC2 where local currency = USD
            $CURRENCY__GBP => 1,
            $CURRENCY__EUR => 1,
        },
        $CURRENCY__EUR => {
            $CURRENCY__GBP => 3,
        },
        $CURRENCY__GBP => {
            $CURRENCY__EUR => 0.5,
        },
        $CURRENCY__HKD => { # helps in DC3 where local currency = HKD
            $CURRENCY__GBP => 1,
            $CURRENCY__EUR => 1,
        },
    },
    tax_currency_conversion_rates => {
        $CURRENCY__USD => { # helps in DC2 where local currency = USD
            $CURRENCY__GBP => 1,
            $CURRENCY__EUR => 1,
        },
        $CURRENCY__EUR => {
            $CURRENCY__GBP => 3,
        },
        $CURRENCY__GBP => {
            $CURRENCY__EUR => 0.5,
        },
        $CURRENCY__HKD => { # helps in DC3 where local currency = HKD
            $CURRENCY__GBP => 1,
            $CURRENCY__EUR => 1,
        },
    },
    wanted_currency_id => $CURRENCY__GBP,
);

my %adj = (
    price_adjustments => [
        {
            start_date => DateTime->now->subtract(years=>2)->epoch,
            end_date   => DateTime->now->subtract(years=>1)->epoch,
            percentage => 60,
        },
        {
            start_date => DateTime->now->subtract(years=>1)->epoch,
            end_date   => DateTime->now->add(years=>1)->epoch,
            percentage => 20,
        },
        {
            start_date => DateTime->now->add(years=>1)->epoch,
            end_date   => DateTime->now->add(years=>2)->epoch,
            percentage => 90,
        },
    ],
);

my $ps = XTracker::Database::PricingService->instance;

{
# here we compare the conversion rate between the last season for
# which we actually have rates, and a later (existing) season. We
# expect not-yet-set rates to be filled forward from the nearest set
# rates

my $latest_season_with_rates =
    $schema->resultset('Public::SeasonConversionRate')->search(
        {},
        {
            join => ['season'],
            prefetch => ['season'],
            order_by => { -desc => ['season.season_year','season.season_code'] },
        }
    )->slice(0,0)->next->season;

my $latest_season =
    $schema->resultset('Public::Season')->search(
        {},
        {
            order_by => { -desc => ['season_year','season_code'] },
        }
    )->slice(0,0)->next;

$ps->_schema($schema);
my $asked_for = $ps->currency_conversion_rates_for_season
    ->{$latest_season_with_rates->id};

# no point testing if we don't have any season without rates
if ($latest_season->compare($latest_season_with_rates) > 0) {
    my $season_for_fallback = _get_next_sane_season( $schema, $latest_season_with_rates );
    note "max known season: @{[ $latest_season->id ]} latest with rates: @{[ $latest_season_with_rates->id ]} using to test: @{[ $season_for_fallback->id ]}";

    my $fallback = $ps->currency_conversion_rates_for_season
        ->{ $season_for_fallback->id };
    is_deeply($fallback,
              $asked_for,
              'currency conversion defaults to most recent season');
}

my $pre=[gettimeofday];
$ps->country_pricing_info;
note "loading country pricing info: ".tv_interval($pre);

$ps->_clear_schema();
}

sub old_price {
    return $ps->round_off(get_product_selling_price($dbh,@_));
}

my @res;

@res = $ps->break_down_price({
    %args,
    country_id => $COUNTRY__UNITED_KINGDOM,
});
is_deeply(\@res,
          [100,0,0],
          'simple pass-through') or diag p @res;

@res = $ps->break_down_price({
    %args,
    country_id => $COUNTRY__FRANCE,
});
is_deeply(\@res,
          [360,0,0],
          'country override and currency conversion') or diag p @res;

@res = $ps->break_down_price({
    %args,
    country_id => $COUNTRY__ITALY,
});
is_deeply(\@res,
          [450,0,0],
          'region override and currency conversion') or diag p @res;

@res = $ps->break_down_price({
    %args,
    %adj,
    country_id => $COUNTRY__UNITED_KINGDOM,
});
is_deeply(\@res,
          [80,0,0],
          'markdown') or diag p @res;

@res = $ps->break_down_price({
    %args,
    %adj,
    country_id => $COUNTRY__FRANCE,
});
is_deeply(\@res,
          [288,0,0],
          'markdown, country override and currency conversion') or diag p @res;

@res = $ps->break_down_price({
    %args,
    %adj,
    country_id => $COUNTRY__ITALY,
});
is_deeply(\@res,
          [360,0,0],
          'markdown, region override and currency conversion') or diag p @res;


@res = $ps->break_down_price({
    %args,
    country_duty_rate => .2,
    country_tax_rate => .2,
    country_id => $COUNTRY__UNITED_KINGDOM,
});
is_deeply(\@res,
          [100,24,20],
          'duty & tax') or diag p @res;

# complex case: 20% tax, plus 20% duty on 60% of the product price
@res = $ps->break_down_price({
    %args,
    duty_rule => 'Product Percentage',
    duty_rule_value => 60,  # yes, this is "in percentage"
    country_duty_rate => .2,# while this is actual factor
    country_tax_rate => .2, # and this one too
    country_id => $COUNTRY__UNITED_KINGDOM,
});
is_deeply(\@res,
          [100,22.4,12],
          'complex duty (prod perc) & tax') or diag p @res;

@res = $ps->break_down_price({
    %args,
    duty_rule => 'Fixed Rate',
    duty_rule_value => 60,  # now this is in source currency
    country_duty_rate => 99, # this should be ignored now
    country_tax_rate => .2,
    country_id => $COUNTRY__UNITED_KINGDOM,
});
is_deeply(\@res,
          [100,32,60],
          'complex duty (fixed) & tax') or diag p @res;

@res = $ps->break_down_price({
    %args,
    duty_rule => 'Fixed Rate',
    duty_rule_value => 60,  # now this is in dc-local currency
    country_duty_rate => 99, # this should be ignored now
    country_tax_rate => .2,
    country_id => $COUNTRY__ITALY,
});
# DC2 considers RRPs to be net, the others consider them to be gross
is_deeply(\@res,
          ( $distribution_centre ne 'DC2' ? [315,75,60] : [450,102,60] ),
          'complex duty (fixed) & tax, with currency conversion') or diag p @res;

@res = $ps->break_down_price({
    %args,
    duty_rule => 'Order Threshold',
    duty_rule_value => 90,      # in dc-local currency
    country_duty_rate => .5,
    tax_rule => 'Order Threshold',
    tax_rule_value => 90,       # in dc-local currency
    country_tax_rate => .5,
    country_id => $COUNTRY__UNITED_KINGDOM,
});
is_deeply(\@res,
          [100,75,50],
          'tax & duty order threshold') or diag p @res;

@res = $ps->break_down_price({
    %args,
    %adj,
    duty_rule => 'Order Threshold',
    duty_rule_value => 90,      # between full and discounted price
    country_duty_rate => .5,
    tax_rule => 'Order Threshold',
    tax_rule_value => 90,       # between full and discounted price
    country_tax_rate => .5,
    country_id => $COUNTRY__UNITED_KINGDOM,
});
is_deeply(\@res,
          [80,0,0],
          'markdown crossing tax & duty order threshold') or diag p @res;

# let's compare with the website, using numbers that Jakub produced on
# 2011-09-06 using
# http://gitosis.net-a-porter.com/cgit/webapp/tree/components/services/src/test/resources/com/netaporter/services/pricing/calculation/ProductPricingCalculatorTest.xml

if ($distribution_centre eq 'DC1') # we don't have samples from AM website
{
my %web_args=(
    schema => $schema,
    default_currency_id => $CURRENCY__GBP,
    default_price => 100,
    country_prices => {
        $COUNTRY__JAPAN => { price => 90, currency_id => $CURRENCY__GBP },
    },
    region_prices => {
        $REGION__EUROPE => { price => 100, currency_id => $CURRENCY__EUR },
    },
    currency_conversion_rates => {
        $CURRENCY__USD => { # helps in DC2 where local currency = USD
            $CURRENCY__GBP => 1,
            $CURRENCY__EUR => 1,
        },
        $CURRENCY__GBP => {
            $CURRENCY__EUR => 1.1817,
            $CURRENCY__USD => 1.5694,
        },
    },
    tax_currency_conversion_rates => {
        $CURRENCY__USD => { # helps in DC2 where local currency = USD
            $CURRENCY__GBP => 1,
            $CURRENCY__EUR => 1,
        },
        $CURRENCY__GBP => {
            $CURRENCY__EUR => 1.1817,
            $CURRENCY__USD => 1.5694,
        },
    },
    #wanted_currency_id => $CURRENCY__GBP,
);
my @test_cases=(
    {
        country => 'GB',
        country_id => $COUNTRY__UNITED_KINGDOM,
        country_tax_rate => 0.20,
        wanted_currency_id => $CURRENCY__GBP,
        expect => [100,20,0],
    },
    {
        country => 'JP',
        country_id => $COUNTRY__JAPAN,
        #country_duty_rate => 0.162,
        country_tax_rate => 0.05,
        #duty_rule => 'Product Percentage',
        #duty_rule_value => 60,
        wanted_currency_id => $CURRENCY__GBP,
        expect => [85.71,4.29,0],
    },
    {
        country => 'CH',
        country_id => $COUNTRY__SWITZERLAND,
        country_tax_rate => 0.08,
        duty_rule => 'Fixed Rate',
        duty_rule_value => 5,
        wanted_currency_id => $CURRENCY__EUR,
        expect => [118.17,9.93,5.91],
    },
    {
        country => 'AU',
        country_id => $COUNTRY__AUSTRALIA,
        country_duty_rate => 0.130,
        country_tax_rate => 0.10,
        tax_rule => 'Order Threshold',
        tax_rule_value => 600,
        duty_rule => 'Order Threshold',
        duty_rule_value => 600,
        wanted_currency_id => $CURRENCY__GBP,
        expect => [100,0,0],
    },
    {
        country => 'BH',
        country_id => $COUNTRY__BAHRAIN,
        country_tax_rate => 0,
        country_duty_rate => 0.05,
        tax_rule => 'Order Threshold',
        tax_rule_value => 380,
        duty_rule => 'Order Threshold',
        duty_rule_value => 380,
        wanted_currency_id => $CURRENCY__GBP,
        expect => [100,0,0],
    },
    {
        country => 'SG',
        country_id => $COUNTRY__SINGAPORE,
        country_tax_rate => 0.07,
        tax_rule => 'Order Threshold',
        tax_rule_value => 200,
        wanted_currency_id => $CURRENCY__GBP,
        expect => [100,0,0],
    },
    {
        country => 'US',
        country_id => $COUNTRY__UNITED_STATES,
        country_tax_rate => 0,
        #country_duty_rate => 0.149,
        wanted_currency_id => $CURRENCY__USD,
        expect => [156.94,0,0],
    },
    {
        country => 'FR',
        country_id => $COUNTRY__FRANCE,
        country_tax_rate => 0.196,
        wanted_currency_id => $CURRENCY__EUR,
        expect => [83.61,16.39,0],
    },
);

for my $case (@test_cases) {
    @res = $ps->break_down_price({
        %web_args,
        %$case,
    });
    is_deeply(\@res,
              $case->{expect},
              $case->{country}.' accords to web');
}
}

$schema->txn_do(sub{
my ( $channel, $pids )  = Test::XTracker::Data->grab_products( {
    channel => 'nap',
    how_many => 1,
    no_markdown => 1,
    phys_vouchers   => {
        how_many => 1,
        value => '110.00',
        currency_id => $CURRENCY__GBP,
    },
    virt_vouchers   => {
        how_many => 1,
        value => '150.00',
        currency_id => $CURRENCY__GBP,
    },
} );

my $prod_chan = $pids->[0]{product_channel};
my $product = $pids->[0]{product};
my $pvouch = $pids->[1]{product};
my $vvouch = $pids->[2]{product};
my $customer = Test::XTracker::Data->find_customer({
    channel_id => $channel->id,
});

my %prod_args = (
    schema => $schema,
    customer_id => $customer->id,
    country_id => $COUNTRY__UNITED_KINGDOM,
    order_total => 510,
    wanted_currency_id => $CURRENCY__GBP,
);
my %vouch_args = (
    schema => $schema,
    customer_id => $customer->id,
    country_id => $COUNTRY__UNITED_KINGDOM,
    order_total => 510,
    wanted_currency_id => $CURRENCY__GBP,
    is_voucher => 1,
);
my %other_args = (
    county              => '',
    country             => 'United Kingdom',
    order_currency_id   => $CURRENCY__GBP,
    customer_id         => $customer->id,
    order_total         => 510,
);

my $ctry_price = $schema->resultset('Public::PriceCountry')->search({
    product_id => $product->id,
    country_id => $COUNTRY__UNITED_KINGDOM,
});
$ctry_price->delete;
my $rgn_price = $schema->resultset('Public::PriceRegion')->search({
    product_id => $product->id,
    region_id => $REGION__EUROPE,
});
$rgn_price->delete;
my $def_price = $schema->resultset('Public::PriceDefault')->find({
    product_id => $product->id
} );
$def_price->update({
    price => 145,
    currency_id => $CURRENCY__GBP,
});

$product->search_related('price_adjustments')->update({
    percentage => 0,
});

@res = $ps->selling_price_for_product({
    %prod_args,
    pid => $product->id,
});
my @other_res = old_price({
    %other_args,
    product_id => $product->id,
});
is_deeply(\@res,
          \@other_res,
          'product price') or diag p @res;

@res = $ps->selling_price_for_product({
    %prod_args,
    wanted_currency_id => $CURRENCY__USD,
    pid => $product->id,
});
@other_res = old_price({
    %other_args,
    order_currency_id => $CURRENCY__USD,
    product_id => $product->id,
});
is_deeply(\@res,
          \@other_res,
          'product price in USD') or diag p @res;

$ctry_price->create({
    currency_id => $CURRENCY__GBP,
    price => 137,
});
@res = $ps->selling_price_for_product({
    %prod_args,
    pid => $product->id,
});
@other_res = old_price({
    %other_args,
    product_id => $product->id,
});
is_deeply(\@res,
          \@other_res,
          'product price w/ country override') or diag p @res;

$rgn_price->create({
    region_id => $REGION__EUROPE,
    currency_id => $CURRENCY__EUR,
    price => 375,
});
@res = $ps->selling_price_for_product({
    %prod_args,
    pid => $product->id,
});
@other_res = old_price({
    %other_args,
    product_id => $product->id,
});
is_deeply(\@res,
          \@other_res,
          'product price w/ country & region override') or diag p @res;
@res = $ps->selling_price_for_product({
    %prod_args,
    country_id => $COUNTRY__FRANCE,
    pid => $product->id,
});
@other_res = old_price({
    %other_args,
    country => 'France',
    product_id => $product->id,
});
is_deeply(\@res,
          \@other_res,
          'product price w/ region override') or diag p @res;

$customer->category->discount(50);$customer->category->update;
@res = $ps->selling_price_for_product({
    %prod_args,
    pid => $product->id,
});
@other_res = old_price({
    %other_args,
    product_id => $product->id,
});
is_deeply(\@res,
          \@other_res,
          'product price with customer discount') or diag p @res;

@res = $ps->selling_price_for_product({
    %prod_args,
    country_id => $COUNTRY__SINGAPORE,
    pid => $product->id,
});
@other_res = old_price({
    %other_args,
    country => 'Singapore',
    product_id => $product->id,
});
is_deeply(\@res,
          \@other_res,
          'product price Singapore') or diag p @res;

@res = $ps->selling_price_for_product({
    %vouch_args,
    pid => $vvouch->id,
});
@other_res = old_price({
    %other_args,
    product_id => $vvouch->id,
});
is_deeply(\@res,
          \@other_res,
          'virtual voucher product price') or diag p @res;

@res = $ps->selling_price_for_product({
    %vouch_args,
    pid => $pvouch->id,
});
@other_res = old_price({
    %other_args,
    product_id => $pvouch->id,
});
is_deeply(\@res,
          \@other_res,
          'physical voucher product price') or diag p @res;


$ps->_schema($schema);
my ($exp_product,$cp,$rp,$cc) = $ps->_expand_product({
    pid => $product->id,
});

my $pre=[gettimeofday];
my $all_countries = $ps->prices_for_all_countries({
    schema => $schema,
    default_price => $exp_product->{price_default}{price},
    default_currency_id => $exp_product->{price_default}{currency_id},
    country_prices => $cp,
    region_prices => $rp,
    price_adjustments => $exp_product->{price_adjustments},
    product_type_id => $exp_product->{product_type_id},
    hs_code_id => $exp_product->{hs_code_id},
    season_id => $exp_product->{season_id},
    customer_id => $customer->id,
    order_total => $other_args{order_total},
});
note "calculating prices for all countries: ".tv_interval($pre);

for my $country_id (keys %$all_countries) {
    my $data = $all_countries->{$country_id};

    my @got = @$data{qw(net tax duty)};
    my $currency_id = $data->{currency_id};
    my $country = $schema->resultset('Public::Country')
        ->find({id=>$country_id})->country;

    my @expected = old_price({
        %other_args,
        country => $country,
        product_id => $product->id,
        order_currency_id => $currency_id,
    });

    is_deeply(\@got,
              \@expected,
              "all_countries matches for $country")
        or do {
            note "got".p $data;
            note "expected".p @expected;
        };

}

$schema->txn_rollback;
});

$schema->txn_do(sub{
# get an arbitrary product_type
my $product_type = $schema->resultset('Public::ProductType')
    ->search(
        { id => { '!=' => 0 } },
        { sort => { -desc => 'id' } },
    )->slice(0,0)->single;
# get a season for which we have conversion rates
my $season = $schema->resultset('Public::SeasonConversionRate')
    ->search(
        {},
        { sort=> { -desc => 'season_id' } }
    )->slice(0,0)->single->season;

my %countries_with_thresholds = map { $_ => 1 }
    $schema->resultset('Public::TaxRuleValue')
    ->search(
        { 'tax_rule.rule' => 'Order Threshold' },
        { join => ['tax_rule'] },
    )->get_column('country_id')->all;

my %args = (
    schema => $schema,
    default_price => 100,
    default_currency_id => $CURRENCY__GBP,
    fulcrum_product_type_id => 12345,
    hs_code_id => 0,
    season_id => $season->id,
);

my $before = $ps->prices_for_all_countries(\%args);

# get any country with no tax/duties
my $country_id = first {
    $before->{$_}{tax} == 0
        && $before->{$_}{duty} == 0
        && ! $countries_with_thresholds{$_}
} sort keys %$before;

my $rate = $schema->resultset('Public::ProductTypeTaxRate')->find_or_create({
    country_id => $country_id,
    product_type_id => $product_type->id,
    fulcrum_reporting_id => 12345,
    rate => 0.5,
});

$ps->clear_country_pricing_info;
my $after = $ps->prices_for_all_countries(\%args);

cmp_deeply($after->{$country_id}{tax},
           num($after->{$country_id}{net} * 0.5,
               $after->{$country_id}{net} * 0.01), # 1% tolerance
           'tax rule applied via Fulcrum reporting id');

$rate->update({rate=>12});

$after = $ps->prices_for_all_countries(\%args);
cmp_deeply($after->{$country_id}{tax},
           num($after->{$country_id}{net} * 0.5,
               $after->{$country_id}{net} * 0.01), # 1% tolerance
           'tax cache not updated yet');

$schema->source("Public::GenerationCounter")
    ->increment_counters('product_type_tax_rate');

$after = $ps->prices_for_all_countries(\%args);
cmp_deeply($after->{$country_id}{tax},
           num($after->{$country_id}{net} * 12,
               $after->{$country_id}{net} * 0.01), # 1% tolerance
           'tax cache updated when counters bumped');

$schema->txn_rollback;
});

done_testing();

#------------------------------------------------------------------

# get the next season id in a sane manner
sub _get_next_sane_season_id {
    my ( $schema, $max_season_id )  = @_;

    my $season_rs   = $schema->resultset('Public::Season');
    my $max_season  = $season_rs->find( $max_season_id );
    my $next_season = $season_rs->search(
            {
                id          => { '>' => $max_season_id },
                season_year => { '>=' => $max_season->season_year },
            },
            {
                order_by    => 'id ASC',
            }
        )->first;

    return $next_season;
}
