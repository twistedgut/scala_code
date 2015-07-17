package XTracker::Database::PricingService;
use NAP::policy "tt", 'class';
use MooseX::Singleton;
use XTracker::Constants::FromDB qw( :country :region :season );
use XTracker::Config::Local qw( config_var );
use List::Util 'first';
use DateTime;

=head1 NAME

XTracker::Database::PricingService

=head1 SYNOPSIS

  use XTracker::Database::PricingService;

  my $ps = XTracker::Database::PricingService->instance;

  my ($net,$tax,$duty) = $ps->selling_price_for_product({
     schema => $dbic_connected_schema,
     pid => $pid,
     country_id => $country_id,
     discount => $customer_discount, # optional
     order_total => $total_price, # optional
  });

  my $full_price_set = $ps->prices_for_all_countries({
     schema => $dbic_connected_schema,
     default_price => $net_price, default_currency_id => $currency_id,
     country_prices => $hash_of_country_price_overrides,
     region_prices => $hash_of_region_price_overrides,
     price_adjustments => $array_of_adjustments_with_dates,
     product_type_id => $product_type_id, # optional
     fulcrum_product_type_id => $fulcrum_reporting_id, # optional
     hs_code_id => $hs_code_id,
     discount => $discount,
     is_voucher => $is_a_voucher,
     order_total => $total_price, # optional
  });

=head1 DESCRIPTION

These functions are used to get pricing information for a product, or
a product as part of an order.

You can just get the broken-down pricing for a given country, or get
the full set of country-specific prices.

=head1 METHODS

=cut

# this gets overwritten by most method calls, it's just a ugly way to
# pass the schema to the builder methods
has _schema => (
    is => 'rw',
    isa => 'DBIx::Class::Schema',
    clearer => '_clear_schema',
);

my %counter_info;

has country_region_map_for_pricing => (
    isa => 'HashRef',
    is => 'ro',
    lazy_build => 1,
);

sub _build_country_region_map_for_pricing {
    my ($self) = @_;

    my $map = {};
    my $country_region_rs =
        $self->_schema->resultset('Public::Country')->search(
            {},
            {
                prefetch => 'sub_region',
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }
        );
    while (my $row = $country_region_rs->next) {
        $map->{$row->{id}}=$row->{sub_region}{region_id};
    }
    # these are in Europe, but not for pricing, so pretend they're not there
    delete $map->{$COUNTRY__UNITED_KINGDOM};
    delete $map->{$COUNTRY__GUERNSEY};
    delete $map->{$COUNTRY__JERSEY};

    return $map;
}

has local_currency_id => (
    isa => 'Int',
    is => 'ro',
    lazy_build => 1,
);

sub _build_local_currency_id {
    my ($self) = @_;

    my $local_currency_code = config_var('Currency', 'local_currency_code');
    my $id = $self->_schema->resultset('Public::Currency')->find({
        currency => $local_currency_code,
    })->id;

    return $id;
}

has xt_instance => (
    isa => 'Str',
    is => 'ro',
    lazy_build => 1,
);
sub _build_xt_instance { config_var('XTracker', 'instance') }

has currency_conversion_rates_for_season => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
);
$counter_info{season}=$counter_info{season_conversion_rate}=
    'clear_currency_conversion_rates_for_season';

sub _build_currency_conversion_rates_for_season {
    my ($self) = @_;

    my $ret = {};

    my @season_ids = map { $_->{id} }
        $self->_schema->resultset('Public::Season')->search(
            {
                season => { '!=' => 'Unknown' },
            },
            {
                order_by => { -asc => [ 'season_year','season_code' ] },
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }
        )->all();

    my @currency_ids = map { $_->{id} }
        $self->_schema->resultset('Public::Currency')->search(
            {
                currency => { '!=' => 'UNK' },
            },
            {
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            }
        )->all();

    my $rs = $self->_schema->resultset('Public::SeasonConversionRate')
        ->search(
            {},
            {
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            },
        );

    while (my $row = $rs->next) {
        $ret->
            {$row->{season_id}}
            {$row->{source_currency_id}}
            {$row->{destination_currency_id}}
                = $row->{conversion_rate};
    }

    # copy missing data from previous seasons
    my $prev_s_slot=$ret->{$season_ids[0]} //= {};
    for my $s_id (@season_ids[1..$#season_ids]) {
        my $s_slot = $ret->{$s_id} //= {};
        for my $sc_id (@currency_ids) {
            my $c_slot = $s_slot->{$sc_id} //= {};
            for my $dc_id (@currency_ids) {
                if (!exists $c_slot->{$dc_id}
                        && exists $prev_s_slot->{$sc_id}{$dc_id}) {
                    $c_slot->{$dc_id} = $prev_s_slot->{$sc_id}{$dc_id}
                }
            }
        }
        $prev_s_slot=$s_slot;
    }

    return $ret;
}

has _currency_conversion_rates_for_date => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
);
$counter_info{sales_conversion_rate}=
    '_clear_currency_conversion_rates_for_date';

sub _build__currency_conversion_rates_for_date {
    my ($self) = @_;

    my $ret = [];

    my $rs = $self->_schema->resultset('Public::SalesConversionRate')
        ->search(
            {},
            {
                order_by => { -asc => 'date_start' },
            },
        );

    while (my $row = $rs->next) {
        push @$ret,{
            start => $row->date_start->epoch,
            finish => ( $row->date_finish ? $row->date_finish->epoch : 0+'+Inf' ), ## no critic(ProhibitMismatchedOperators)
            src => $row->get_column('source_currency'),
            dest => $row->get_column('destination_currency'),
            rate => $row->conversion_rate,
        }
    }

    return $ret;
}

sub currency_conversion_rates_for_date {
    my ($self,$date) = @_;

    my $convs = $self->_currency_conversion_rates_for_date;

    my $ret={};

    for my $c (@$convs) {
        next unless $c->{start} <= $date and $c->{finish} > $date;
        $ret->{$c->{src}}{$c->{dest}}=$c->{rate};
    }

    return $ret;
}

=head2 C<break_down_price>

Method mostly for internal use.

  my ($net,$tax,$duty) = $ps->break_down_price({
     schema => $dbic_connected_schema,
     default_price => $net_price, default_currency_id => $currency_id,
     country_prices => $hash_of_country_price_overrides,
     region_prices => $hash_of_region_price_overrides,
     price_adjustments => $array_of_adjustments_with_dates,
     country_duty_rate => $duty_rate,
     country_tax_rate => $tax_rate,
     product_type_tax_rate => $pt_tax_rate,
     discount => $discount,
     currency_conversion_rates => $hash_of_conversion_rates,
     tax_currency_conversion_rates => $hash_of_conversion_rates,
     duty_rule => $drule_name, duty_rule_value => $drvalue,
     tax_rule => $trule_name, tax_rule_value => $trvalue,
     country_id => $country_id,
     wanted_currency_id => $currency_id,
     is_voucher => $is_a_voucher,
     order_total => $total_price, # optional
  });

If it's a voucher, pass the voucher value as "default
price". Conversion rates are relative to the season you want.  Price
adjustments are assumed sorted by increasing start_date.

=cut

sub break_down_price {
    my ($self,$args) = @_;

    my $conv_rate_from = sub {
        my $dest = shift;
        my $tax = shift // 0;
        my $src = $args->{wanted_currency_id};
        return 1 if $dest == $src;
        my $ret = $args->{
            $tax ? 'tax_currency_conversion_rates'
                 : 'currency_conversion_rates'
            }{$dest}{$src};
        if (!defined $ret) {
            croak "No conversion rate known between $dest and $args->{wanted_currency_id}";
        }
        return $ret;
    };

    if ($args->{is_voucher}) {
        my $net = $args->{default_price};
        if ($args->{wanted_currency_id} != $args->{default_currency_id}) {
            $net *= $conv_rate_from->($args->{default_currency_id});
        }
        return $self->round_off($net,0,0);
    }

    my $country_region_map = $args->{country_region_map_for_pricing};

    my $local_currency_id = $args->{local_currency_id};

    if (!$country_region_map || !$local_currency_id) {
        my $schema = $args->{schema};

        # not a voucher, we need to check the overrides
        $self->_schema($schema);
        $country_region_map //= $self->country_region_map_for_pricing;
        $local_currency_id //= $self->local_currency_id;
        $self->_clear_schema;
    }

    my $override =
        $args->{country_prices}{$args->{country_id}}
        ||
        $args->{region_prices}{
            $country_region_map->{$args->{country_id}} // 0
        };
    my ($price,$source_currency_id,$is_net) =
        $override ? (
            $override->{price},
            $override->{currency_id},
            0
        ) : (
            $args->{default_price},
            $args->{default_currency_id},
            1
        );

    if ($args->{wanted_currency_id} != $source_currency_id) {
        $price *= $conv_rate_from->($source_currency_id);
    }

    # markdowns / price adjustments
    if ($args->{price_adjustments}) {
        my $now= $args->{datetime} // DateTime->now->epoch;
        for my $adj (@{$args->{price_adjustments}}) {
            if  ($adj->{start_date} <= $now && $adj->{end_date} > $now ) {
                my $markdown = $adj->{percentage};
                if ($markdown) {
                    $price *= (100-$markdown)/100;
                }
                last;
            }
        }
    }

    # customer (or other) discounts
    if ($args->{discount}) {
        $price *= (100-$args->{discount})/100;
    }

    my $total = $args->{order_total} // $price;

    my $conv_rate_from_local = $conv_rate_from->($local_currency_id,1);

    my ($duty_threshold,$duty_percentage,$duty_fixed_rate)=(0,1,0);
    $args->{duty_rule} //= '';
    if ($args->{duty_rule} eq 'Product Percentage') {
        $duty_percentage = $args->{duty_rule_value} / 100;
    }
    elsif ($args->{duty_rule} eq 'Order Threshold') {
        $duty_threshold = $args->{duty_rule_value} * $conv_rate_from_local;
    }
    elsif ($args->{duty_rule} eq 'Fixed Rate') {
        $duty_fixed_rate = $args->{duty_rule_value} * $conv_rate_from_local;
    }

    my ($tax_threshold,$tax_custom_modifier,$tax_rate)=(0,1,0);
    $args->{tax_rule} //= '';
    if ($args->{tax_rule} eq 'Order Threshold') {
        $tax_threshold = $args->{tax_rule_value}
            * $conv_rate_from_local;
    }
    elsif ( $args->{tax_rule} eq 'Custom Modifier' ) {
        $tax_custom_modifier = $args->{tax_rule_value} / 100;
    }

    $tax_rate = $args->{product_type_tax_rate} // $args->{country_tax_rate} // 0;

    my $duty = 0;
    if ($total >= $duty_threshold) {
        if ($duty_fixed_rate) {
            $duty = $duty_fixed_rate;
        }
        else {
            $duty = $price * $duty_percentage * ($args->{country_duty_rate}//0);
        }
    }

    my $tax = 0;
    if ($total >= $tax_threshold) {
        # yes, if it's 0 we assume it means "don't apply it", i.e. 1
        $tax = ($price + $duty) / ($tax_custom_modifier || 1) * $tax_rate;
    }

    # if UK system and price is an RRP then tax and duty need to be taken off rather than added on
    my $product_selling_price = config_var( 'Pricing', 'ProductSellingPrice' );
    if ($product_selling_price->{remove_vat} && ! $is_net){

        if ($total >= $tax_threshold) {
            my $less_tax = $price / (1 + $tax_rate);
            $tax = $price - $less_tax;
            $price = $less_tax;
        }

        if ($total >= $duty_threshold) {
            if ($duty_fixed_rate){
                $price = $price - $duty_fixed_rate;
            }
            else {
                my $less_duty = $price / (1 + ( $duty_percentage * ($args->{country_duty_rate}//0) ));
                $duty = $price - $less_duty;
                $price = $less_duty;
            }
        }
    }

    return $self->round_off($price,$tax,$duty);
}

=head2 C<selling_price_for_product>

  my ($net,$tax,$duty) = $ps->selling_price_for_product({
     schema => $dbic_connected_schema,
     pid => $pid,
     country_id => $country_id,
     discount => $customer_discount, # optional
     order_total => $total_price, # optional
  });

This function should do the same thing as
C<XTracker::Database::Pricing::get_product_selling_price>

=cut

sub _expand_product {
    my ($self,$args) = @_;

    my $s = $self->_schema;

    if ($args->{is_voucher}) {

        my $voucher = $s->resultset('Voucher::Product')->search({
            id => $args->{pid},
        },{
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        })->single;

        my $cc
            = $self->currency_conversion_rates_for_season->{$SEASON__CONTINUITY};

        return ($voucher, {}, {}, $cc);

    }

    my $product = $s->resultset('Public::Product')->search({
        'me.id' => $args->{pid},
    },{
        prefetch => 'price_default',
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    })->first;

    my @price_country = $s->resultset('Public::PriceCountry')->search({
        'product_id' => $args->{pid},
    },{
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    })->all;
    my @price_region = $s->resultset('Public::PriceRegion')->search({
        'product_id' => $args->{pid},
    },{
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    })->all;
    my @price_adj = $s->resultset('Public::PriceAdjustment')->search({
        'product_id' => $args->{pid},
    },{
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    })->all;

    my %cp = map { $_->{country_id}, $_ } @price_country;
    my %rp = map { $_->{region_id}, $_ } @price_region;
    for my $adj (@price_adj) {
        $adj->{start_date} = DateTime::Format::ISO8601
            ->parse_datetime($adj->{date_start} =~ s{ }{T}r)
                ->set_time_zone('UTC')->epoch;
        $adj->{end_date} = DateTime::Format::ISO8601
            ->parse_datetime($adj->{date_finish} =~ s{ }{T}r)
                ->set_time_zone('UTC')->epoch;
    }
    $product->{price_adjustments} = \@price_adj;
    my $cc = $self->currency_conversion_rates_for_season->{$product->{season_id}};

    return ($product,\%cp,\%rp,$cc);
}

sub _expand_discount {
    my ($self,$args) = @_;

    return $args->{discount} if defined $args->{discount};

    if ($args->{customer_id}) {
        my $customer =
            $self->_schema->resultset('Public::Customer')->search({
                'me.id' => $args->{customer_id},
            },{
                prefetch => [
                    'category',
                ],
                result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            })->next;
        return $customer->{category}{discount};
    }

    return;
}

has _generation_counters => (
    is => 'rw',
    isa => 'HashRef',
    lazy_build => 1,
);

has auto_invalidate_cache => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
);

sub _build__generation_counters {
    my ($self) = @_;
    return $self->_schema->source("Public::GenerationCounter")
        ->get_counters(keys %counter_info);
}

sub _check_generation_counters {
    my ($self) = @_;

    return unless $self->auto_invalidate_cache;

    my %changed = %{$self->_schema->source("Public::GenerationCounter")
        ->get_changed($self->_generation_counters)};

    for my $counter (keys %changed) {
        my $clearer = $counter_info{$counter};
        $self->$clearer();
    }
    # update stored values with changed ones
    $self->_generation_counters({
        %{$self->_generation_counters},
        %changed,
    });
}

has country_pricing_info => (
    is => 'ro',
    isa => 'HashRef',
    lazy_build => 1,
);
$counter_info{country}=$counter_info{country_duty_rate}=
    $counter_info{product_type_tax_rate}=$counter_info{country_tax_rate}=
    $counter_info{tax_rule_value}=$counter_info{duty_rule_value}=
    'clear_country_pricing_info';

sub _build_country_pricing_info {
    my ($self) = @_;

    my $rs = $self->_schema->resultset('Public::Country')->search({
        'me.id' => { '!=' => 0 },
    },{
        prefetch => [
            'country_duty_rates',
            'product_type_tax_rates',
            'country_tax_rate',
            {'tax_rule_values' => 'tax_rule'},
            {'duty_rule_values' => 'duty_rule'},
        ],
        result_class => 'DBIx::Class::ResultClass::HashRefInflator',
    });

    # silence DBIC warnings about multiple has_many prefetches
    # we know it will return the right data
    my @countries = do {
        local $SIG{__WARN__}=sub{};
        $rs->all;
    };

    my %ret = map { $_->{id} => $_ } @countries;
    for my $country (values %ret) {
        $country->{country_duty_rates} = {
            map { $_->{hs_code_id} => $_ }
                @{$country->{country_duty_rates}}
        };
        $country->{product_type_tax_rates_fulcrum} = {
            map { $_->{fulcrum_reporting_id} => $_ }
            grep { defined $_->{fulcrum_reporting_id} }
                @{$country->{product_type_tax_rates}}
        };
        $country->{product_type_tax_rates} = {
            map { $_->{product_type_id} => $_ }
                @{$country->{product_type_tax_rates}}
        };
    }

    return \%ret;
}

sub _expand_country {
    my ($self,$product,$country) = @_;

    my $cdr = $country->{country_duty_rates}{ $product->{hs_code_id} };
    my $pttr;
    $pttr = $country->{product_type_tax_rates}{ $product->{product_type_id} }
        if exists $product->{product_type_id};
    $pttr = $country->{product_type_tax_rates_fulcrum}{ $product->{fulcrum_product_type_id} }
        if exists $product->{fulcrum_product_type_id};

    return ($cdr,$pttr);
}

sub selling_price_for_product {
    my ($self,$args) = @_;

    my $schema = $args->{schema};
    $self->_schema($schema);
    $self->_check_generation_counters;

    my $discount = $self->_expand_discount($args);
    my ($product,$cp,$rp,$cc) = $self->_expand_product($args);
    my $country = $self->country_pricing_info->{$args->{country_id}};

    my ($cdr, $pttr);
    if ($args->{is_voucher}) {
        $cdr = 0; $pttr = 0
    }
    else {
        ($cdr,$pttr) = $self->_expand_country($product,$country);
    }

    my $tcc = $self->currency_conversion_rates_for_date(
        $args->{datetime} || DateTime->now->epoch # yes, 0 means "now" here
    );

    $self->_clear_schema;

    my %bdp_args = (
        default_price => $args->{is_voucher} ? $product->{value} : $product->{price_default}{price},
        default_currency_id => $args->{is_voucher} ? $product->{currency_id} : $product->{price_default}{currency_id},
        country_prices => $cp,
        region_prices => $rp,
        price_adjustments => $product->{price_adjustments},
        country_tax_rate => $country->{country_tax_rate}{rate},
        ( $cdr ? (country_duty_rate => $cdr->{rate}): ()),
        ( $pttr ? (product_type_tax_rate => $pttr->{rate}) : ()),
        discount => $discount,
        currency_conversion_rates => $cc,
        tax_currency_conversion_rates => $tcc,
        duty_rule => $country->{duty_rule_values}[0]{duty_rule}{rule},
        duty_rule_value => $country->{duty_rule_values}[0]{value},
        tax_rule => $country->{tax_rule_values}[0]{tax_rule}{rule},
        tax_rule_value => $country->{tax_rule_values}[0]{value},
        country_id => $args->{country_id},
        wanted_currency_id => $args->{wanted_currency_id} // $country->{currency_id},
        is_voucher => $args->{is_voucher} // 0,
        order_total => $args->{order_total},
        datetime => $args->{datetime},
    );

    return $self->break_down_price({
                schema => $schema,
                %bdp_args,
            });
}

=head2 C<prices_for_all_countries>

  my $full_price_set = $ps->prices_for_all_countries({
     schema => $dbic_connected_schema,
     default_price => $net_price, default_currency_id => $currency_id,
     country_prices => $hash_of_country_price_overrides,
     region_prices => $hash_of_region_price_overrides,
     price_adjustments => $array_of_adjustments_with_dates,
     product_type_id => $product_type_id, # optional
     fulcrum_product_type_id => $fulcrum_reporting_id, # optional
     hs_code_id => $hs_code_id,
     discount => $discount,
     is_voucher => $is_a_voucher,
     order_total => $total_price, # optional
  });

Returns a hashref keyed off country ids, whose values are hashes with
keys C<net>, C<tax>, C<duty> and C<currency_id>.

=cut

sub __slice {
    my ($hashref,@keys) = @_;

    map { exists $hashref->{$_} ? ($_, $hashref->{$_}) : () } @keys;
}

sub prices_for_all_countries {
    my ($self,$args) = @_;

    my $schema = $args->{schema};
    $self->_schema($schema);
    $self->_check_generation_counters;

    my $discount = $self->_expand_discount($args);
    my $cc = $self->currency_conversion_rates_for_season->{$args->{season_id}};
    my $local_currency_id = $self->local_currency_id;
    my $country_pricing_info = $self->country_pricing_info;
    my $country_region_map = $self->country_region_map_for_pricing;
    my $tcc = $self->currency_conversion_rates_for_date(
        $args->{datetime} || DateTime->now->epoch # yes, 0 means "now" here
    );

    $self->_clear_schema;

    my $ret;
    my %bdp_args = (
        __slice($args,qw(
                            default_price
                            default_currency_id
                            country_prices
                            region_prices
                            price_adjustments
                            product_type_tax_rate
                            is_voucher
                            order_total
                            datetime
                    )),
        discount => $discount,
        currency_conversion_rates => $cc,
        tax_currency_conversion_rates => $tcc,
        local_currency_id => $local_currency_id,
        country_region_map_for_pricing => $country_region_map,
        xt_instance => $self->xt_instance,
    );
    $bdp_args{default_currency_id} //= $local_currency_id;
    $bdp_args{datetime} //= DateTime->now()->epoch;

    for my $country (values %{$country_pricing_info}) {

        my ($cdr,$pttr) = $self->_expand_country($args,$country);

        my %bdp_per_country_args = (
            country_tax_rate => $country->{country_tax_rate}{rate},
            ( $cdr ? (country_duty_rate => $cdr->{rate}) : ()),
            ( $pttr ? (product_type_tax_rate => $pttr->{rate}) : ()),
            duty_rule => $country->{duty_rule_values}[0]{duty_rule}{rule},
            duty_rule_value => $country->{duty_rule_values}[0]{value},
            tax_rule => $country->{tax_rule_values}[0]{tax_rule}{rule},
            tax_rule_value => $country->{tax_rule_values}[0]{value},
            country_id => $country->{id},
            wanted_currency_id => $country->{currency_id} || $local_currency_id,
        );

        my ($net,$tax,$duty) = $self->break_down_price({
            schema => $schema,
            %bdp_args,
            %bdp_per_country_args,
        });

        $ret->{$country->{id}} = {
            net => $net,
            tax => $tax,
            duty => $duty,
            currency_id => $bdp_per_country_args{wanted_currency_id},
        };
    }

    return $ret;
}

# XXX this is clearly stupid at the moment

sub round_off {
    my ($self,@triplets) = @_;

    return unless @triplets;

    if (ref $triplets[0]) {
        return map { map { 0+(sprintf "%.2f", $_) } @$_ } @triplets;
    }
    else {
        return map { 0+(sprintf "%.2f", $_) } @triplets;
    }
}
