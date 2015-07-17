package Test::XT::DC::Controller::Pricing;
use NAP::policy "tt", 'test';
use mro;
use parent 'NAP::Test::Class';
use XTracker::Config::Local qw( config_var );
use Test::XTracker::Data;
use HTTP::Request::Common;
use DateTime;
use JSON;
use Catalyst::Test 'XT::DC';

sub _get_one {
    my ($self,$rs,%etc) = @_;
    $self->{schema}->resultset($rs)
        ->search({id=>{'!='=>0},%etc})->slice(0,0)->single;
}

sub startup :Test(startup) {
    my ($self) = @_;
    $self->next::method;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{dc_name} = config_var('DistributionCentre','name');
    $self->{channel} = Test::XTracker::Data->get_local_channel();
    $self->{hs_code} = $self->_get_one('Public::HSCode');
    my $max_season_id_with_rates = $self->{schema}
        ->resultset('Public::SeasonConversionRate')
            ->search(
                {},
                {
                    select => [{max=>'season_id'}],
                    as => 'max_season_id',
                    result_class => 'DBIx::Class::ResultClass::HashRefInflator',
                }
            )->next->{max_season_id};
    $self->{season} = $self->_get_one('Public::Season',
                                      id=>$max_season_id_with_rates,
                                  );
    $self->{currency_code} = config_var('Currency', 'local_currency_code');

    $self->{product_type_tax_rate} =
        $self->{schema}->resultset('Public::ProductTypeTaxRate')->search({
            rate => { '>' => 0 },
            -or => [
                product_type_id => { '!=' => { -ident => 'fulcrum_reporting_id' } },
                fulcrum_reporting_id => undef,
            ],
        })->slice(0,0)->single;
    $self->{old_repcat_id} = $self->{product_type_tax_rate}->fulcrum_reporting_id;

    note sprintf 'Running on %s, currency %s, season %s',
        $self->{dc_name},$self->{currency_code},
            $self->{season}->season;
}

sub teardown :Test(teardown) {
    my ($self) = @_;

    $self->{product_type_tax_rate}->update({fulcrum_reporting_id => $self->{old_repcat_id}});

    $self->next::method;
}

sub do_request {
    my ($self,$data,$expect_error) = @_;

    my %data_with_defs = (
        channel_id => $self->{channel}->id,
        default_currency => $self->{currency_code},
        hs_code => $self->{hs_code}->hs_code,
        season => $self->{season}->season,
        is_voucher => 0,
        when => DateTime->now->iso8601,
        %$data,
    );

    my $req_payload = encode_json(\%data_with_defs);
    my $response = request
        POST '/pricing/prices_for_all_countries',
            'Content-Type' => 'application/json',
            Content => $req_payload,
            ;
    if (not $response->is_success and not $expect_error) {
        note p $response;
        die $response->status_line;
    }
    ok($response->is_error, "error returned") if $expect_error;
    return decode_json($response->content);
}

sub purge_caches {
    my ($self) = @_;

    request POST '/pricing/reload_cache',
        'Content-Type' => 'application/json',
            ;
}

sub simple_request :Tests {
    my ($self) = @_;

    my $response = $self->do_request({
        default_price => 100,

    });

    # yes, the request uses dc-local currency from the config, but the
    # test uses hard-coded expected values; if the dc-local currency
    # ever changes, something quite probably went wrong!
    my $expected;
    if ($self->{dc_name} eq 'DC1') {
        $expected = { GB => {
            currency => 'GBP',
            net => 100,
            tax => 20,
            duty => 0,
        } };
    }
    elsif ($self->{dc_name} eq 'DC2') {
        $expected = { US => {
            currency => 'USD',
            net => 100,
            tax => 0,
            duty => 0,
        } };
    }
    elsif ($self->{dc_name} eq 'DC3') {
        $expected = { HK => {
            currency => 'HKD',
            net => 100,
            tax => 0,
            duty => 0,
        } };
    }
    cmp_deeply($response,
               superhashof($expected),
               'correct price');
}

sub error_requests :Tests  {
    my ($self) = @_;

    my $response = $self->do_request({
        default_price => 'invalid',
    }, 'expect_error');

    cmp_deeply($response,
               { error => 'Problems: Badly formed input data' },
               "Badly formed request reported correctly");

    for my $field (qw(default_currency hs_code season)) {
        my $response = $self->do_request({
            default_price => 100,
            $field => 'invalid',
        }, 'expect_error');
        cmp_deeply($response,
                   { error => "Problems: Invalid $field value: 'invalid'" },
                   "Invalid $field value reported correctly");
    }
    for my $type (qw(country region)) {
        my $response = $self->do_request({
            default_price => 100,
            "${type}_prices" => {
                invalid => {
                    currency => $self->{currency_code},
                    price => 123,
                }
            },
        }, 'expect_error');
        cmp_deeply($response,
                   {error => "Problems: Invalid $type value: 'invalid'" },
                   "Invalid $type name reported correctly");
    }
}

sub request_with_product_type :Tests {
    my ($self) = @_;

    my $product_type_tax_rate = $self->{product_type_tax_rate};
    my $rate = $product_type_tax_rate->rate;
    my $country = $product_type_tax_rate->country->code;
    my $type_id = $product_type_tax_rate->product_type_id;

    note sprintf 'type %d country %s rate %g',
        $type_id,$country,$rate;

    my $response = $self->do_request({
        default_price => 100,
    });
    my $no_product_type = $response->{$country};

    $response = $self->do_request({
        default_price => 100,
        product_type_id => $type_id,
    });
    my $xt_product_type = $response->{$country};

    cmp_deeply($xt_product_type,
               $no_product_type,
               'using XT product type ids has no effect');

    if (not defined $self->{old_repcat_id}) {
        $product_type_tax_rate->update({fulcrum_reporting_id=>9999});
    }
    my $repcat_id = $product_type_tax_rate->fulcrum_reporting_id;

    $response = $self->do_request({
        default_price => 100,
        product_type_id => $repcat_id,
    });
    my $repcat_product_type = $response->{$country};

    cmp_deeply($repcat_product_type,
               $no_product_type,
               'using Fulcrum product type ids w/o purging caches has no effect');

    $self->purge_caches;

    $response = $self->do_request({
        default_price => 100,
        product_type_id => $repcat_id,
    });
    $repcat_product_type = $response->{$country};

    cmp_deeply($repcat_product_type,
               {
                   %$no_product_type,
                   tax => num(
                       ($no_product_type->{net}+$no_product_type->{duty})*$rate,
                       0.01
                   ),
               },
               'using Fulcrum product type ids now works')
        or do {
            note 'No product type: ',p $no_product_type;
            note 'With product type: ',p $repcat_product_type;
        };
}
