package XT::DC::Controller::Pricing;
use NAP::policy "tt", 'class';
BEGIN { extends 'Catalyst::Controller::REST' }
use XTracker::Database::PricingService;
use DateTime::Format::ISO8601;
use Data::BiMapFromDB;
use XT::DC::Types::Pricing 'PricingRequest';
use List::Util 'sum';
use XTracker::Config::Local 'config_var';

sub prices_for_all_countries :Local :ActionClass('REST') {
}
sub reload_cache :Local :ActionClass('REST') {
}

my %map_info = (
    currency => '_currencies',
    country => '_countries',
    region => '_regions',
    hs_code => '_hs_codes',
    season => '_seasons',
);

for my $attr (values %map_info) {
    has $attr => (
        isa => 'Data::BiMapFromDB',
        is => 'ro',
        lazy => 1,
        builder => '_empty_map',
        clearer => "_clear$attr",
    );
}
sub _empty_map { Data::BiMapFromDB->new() }

sub _build_maps {
    my ($self,$schema) = @_;

    $self->_currencies->load($schema,'Public::Currency','id','currency');
    $self->_countries->load($schema,'Public::Country','id','code');
    $self->_regions->load($schema,'Public::Region','id','region');
    $self->_hs_codes->load($schema,'Public::HSCode','id','hs_code');
    $self->_seasons->load($schema,'Public::Season','id','season');

    return;
}

has _generation_counters => (
    is => 'rw',
    isa => 'HashRef',
);

has auto_invalidate_cache => (
    is => 'rw',
    isa => 'Bool',
    default => sub { config_var('Controller::Pricing','auto_invalidate_cache') },
);

sub _load_generation_counters {
    my ($self,$schema) = @_;
    return if $self->_generation_counters;
    $self->_generation_counters(
        $schema->source("Public::GenerationCounter")
            ->get_counters(keys %map_info)
        );
}

sub _check_generation_counters {
    my ($self,$schema) = @_;

    if ($self->auto_invalidate_cache) {
        $self->_load_generation_counters($schema);
        my %changed = %{$schema->source("Public::GenerationCounter")
           ->get_changed($self->_generation_counters)};

        for my $counter (keys %changed) {
            my $attr = $map_info{$counter};
            my $clearer = "_clear$attr";
            $self->$clearer();
        }
        # update stored values with changed ones
        $self->_generation_counters({
            %{$self->_generation_counters},
            %changed,
        });
    }

    $self->_build_maps($schema);
}

sub BUILD {
    my ($self) = @_;
    # propagate configured value
    XTracker::Database::PricingService->instance->auto_invalidate_cache(
        $self->auto_invalidate_cache,
    );
}

sub _munge_input {
    my ($self,$input) = @_;

    die "Badly formed input data\n"
        unless is_PricingRequest($input);

    my %munged = (
        default_price => $input->{default_price},
        is_voucher => $input->{is_voucher},
        default_currency_id => $self->_currencies
            ->id_for($input->{default_currency}),
        hs_code_id => $self->_hs_codes
            ->id_for($input->{hs_code}//'Unknown'),
        # Only pass through product type if it's passed by ID,
        # since the names are changeable and can be out of sync
        (exists $input->{product_type_id} ? (
            fulcrum_product_type_id => $input->{product_type_id},
        ) : ()),
        season_id => $self->_seasons
            ->id_for($input->{season}),
    );

    for my $field (qw(default_currency hs_code season)) {
        die "Invalid $field value: '$input->{$field}'\n"
            unless defined $munged{"${field}_id"};
    }

    for my $country (keys %{$input->{country_prices}//{}}) {
        my $price = $input->{country_prices}{$country};
        my $country_id = $self->_countries->id_for($country)
            or die "Invalid country value: '$country'\n";

        $munged{country_prices}{$country_id} = {
            price => $price->{price},
            currency_id => $self->_currencies
                ->id_for($price->{currency})
                    || die "Invalid currency value '$price->{currency}'\n" ,
        };
    }

    for my $region (keys %{$input->{region_prices}//{}}) {
        my $price = $input->{region_prices}{$region};
        my $region_id = $self->_regions->id_for($region)
            or die "Invalid region value: '$region'\n";

        $munged{region_prices}{$region_id} = {
            price => $price->{price},
            currency_id => $self->_currencies
                ->id_for($price->{currency})
                    || die "Invalid currency value '$price->{currency}'\n" ,
        };
    }

    # dates can be given as UNIX epoch, or full ISO 8601 strings

    for my $pa (@{$input->{price_adjustments}//[]}) {
        my $ret = {
            percentage => $pa->{percentage},
        };
        for my $f (qw(start_date end_date)) {
            my $v = $pa->{$f};
            if ($v =~ m{\D}) {
                $v = DateTime::Format::ISO8601
                    ->parse_datetime($v)->set_time_zone('UTC')
                        ->epoch;
            }
            $ret->{$f}=$v;
        }
        push @{$munged{price_adjustments}}, $ret;
    }

    $munged{datetime} = $input->{when};
    if ($munged{datetime} =~ m{\D}) {
        $munged{datetime} = DateTime::Format::ISO8601
        ->parse_datetime($input->{when})->set_time_zone('UTC')
            ->epoch;
    }

    return \%munged;
}

sub _munge_output {
    my ($self,$output) = @_;

    my %munged = ( );
    for my $country_id (keys %$output) {
        my $prices = $output->{$country_id};
        my $country = $self->_countries->name_for($country_id);
        my $currency = $self->_currencies->name_for($prices->{currency_id});

        $munged{$country} = {
            net => $prices->{net},
            tax => $prices->{tax},
            duty => $prices->{duty},
            currency => $currency,
        };
    }

    return \%munged;
}

sub prices_for_all_countries_POST {
    my ($self,$c) = @_;

    my $schema = $c->model('DB')->schema;
    $self->_check_generation_counters($schema);

    my $ret;
    try {
        my $args = $self->_munge_input($c->req->data);
        $ret = XTracker::Database::PricingService->instance
            ->prices_for_all_countries({
                schema => $schema,
                %$args,
            });
        $self->status_ok(
            $c,
            entity => $self->_munge_output($ret),
        );
    }
    catch {
        chomp;
        $self->status_bad_request(
            $c,
            message => "Problems: $_",
        );
    };
    return;
}

sub reload_cache_POST {
    my ($self,$c) = @_;

    for my $f (qw(_currencies _countries _regions _hs_codes _seasons)) {
        $self->$f->clear();
    }

    my $ps = XTracker::Database::PricingService->instance;
    for my $m ('clear_country_region_map_for_pricing',
               'clear_local_currency_id',
               'clear_currency_conversion_rates_for_season',
               '_clear_currency_conversion_rates_for_date',
               'clear_country_pricing_info') {
        $ps->$m();
    }

    $self->status_ok(
        $c,
        entity => {}
    );
    return;
}
