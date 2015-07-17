package XT::DC::Types::Pricing;
use strict;
use warnings;
use MooseX::Types -declare => ['PricingRequest','PriceMap','DateString'];
use MooseX::Types::Structured qw(Map Dict Optional);
use MooseX::Types::Moose qw(ArrayRef Str Int Num Undef);

subtype DateString,
    as Str,
    where { eval { DateTime::Format::ISO8601->parse_datetime($_) } };

subtype PriceMap,
    as Map[
        Str ,=> Dict[
            currency => Str,
            price => Num,
        ]];

subtype PricingRequest,
    as Dict[
        channel_id => Int,
        default_price => Num,
        default_currency => Optional[Str],
        product_type => Optional[Str|Undef], # ignored, use _id
        product_type_id => Optional[Int], # this is the *Fulcrum* id for the 2nd level reporting category
        hs_code => Optional[Str],
        season => Str,
        is_voucher => Int,
        discount => Optional[Num],
        country_prices => Optional[PriceMap],
        region_prices => Optional[PriceMap],
        when => DateString,
        price_adjustments => Optional[ArrayRef[Dict[
            percentage => Num,
            start_date => DateString,
            end_date => DateString,
            category => Optional[Str],
        ]]],
        order_total => Optional[Num],
    ];

1;
