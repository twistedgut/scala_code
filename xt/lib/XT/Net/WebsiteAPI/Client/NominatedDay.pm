package XT::Net::WebsiteAPI::Client::NominatedDay;
use NAP::policy "tt", "class";
extends "XT::Net::WebsiteAPI::Client";

use Moose::Util::TypeConstraints;
use MooseX::Params::Validate;

=head1 NAME

XT::Net::WebsiteAPI::Client::NominatedDay - API Client for making Nominated Day related calls

=head1 METHODS

=head2 available_dates({ :$sku!, :$country!, :$postcode!, :$state? }) : @$rows[ $inflate_into_class ]

Make a request to get Nominated Day / available dates in the near
future by providing a shipping SKU, a $country (e.g. "GB"), a
$postcode (e.g. "W6 0NJ"), and an optional state (e.g. "NY").

Return an array ref with XT::Net::WebsiteAPI::Response::AvailableDate
objects, or die on errors.

=cut

subtype "CountryCode",
    as "Str",
    where { /^ [A-Z]{2} $/x };

subtype "StateCode",
    as "Str",
    where { /^ [A-Z]{2} $/x };

subtype "EmptyString",
    as "Str",
    where { /^ $/x };

sub available_dates {
    my ($self, %args) = validated_hash( \@_,
        sku      => { isa => 'Str',                             required => 1 },
        postcode => { isa => 'Str',                             required => 1 },
        country  => { isa => "CountryCode",                     required => 1 },
        state    => { isa => "StateCode | Undef | EmptyString", optional => 1 },
    );

    $self->is_sku_nominated_day($args{sku}) or return []; # Call API only if needed

    return $self->get({
        path             => "shipping/nominatedday/availabledate.json",
        arg_names_values => \%args,
        inflate_into     => "XT::Net::WebsiteAPI::Response::AvailableDate",
    });
}

=head2 is_sku_nominated_day($sku) : Bool or die

Boolean, whether Ssku is for a Nominated Day Shipping Charge, and
hence can have any Available Dates.

=cut
sub is_sku_nominated_day {
    my ($self, $sku) = @_;
    return $self->find_shipping_charge_sku($sku)->is_nominated_day;
}

1;
