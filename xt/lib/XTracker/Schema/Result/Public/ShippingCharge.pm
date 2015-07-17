use utf8;
package XTracker::Schema::Result::Public::ShippingCharge;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipping_charge");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping_charge_id_seq",
  },
  "sku",
  { data_type => "varchar", is_nullable => 0, size => 20 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "charge",
  { data_type => "numeric", is_nullable => 0, size => [10, 2] },
  "currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "flat_rate",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "class_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "latest_nominated_dispatch_daytime",
  { data_type => "time", is_nullable => 1 },
  "premier_routing_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "is_enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "is_customer_facing",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "is_return_shipment_free",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
  "is_express",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "is_slow",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("unique_shipping_charge_sku", ["sku"]);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "country_charges",
  "XTracker::Schema::Result::Shipping::CountryCharge",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_shipping_charges",
  "XTracker::Schema::Result::Public::CountryShippingCharge",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "delivery_date_restrictions",
  "XTracker::Schema::Result::Shipping::DeliveryDateRestriction",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "postcode_shipping_charges",
  "XTracker::Schema::Result::Public::PostcodeShippingCharge",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_orders",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "premier_routing",
  "XTracker::Schema::Result::Public::PremierRouting",
  { id => "premier_routing_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "region_charges",
  "XTracker::Schema::Result::Shipping::RegionCharge",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ship_restriction_allowed_shipping_charges",
  "XTracker::Schema::Result::Public::ShipRestrictionAllowedShippingCharge",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipments",
  "XTracker::Schema::Result::Public::Shipment",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "shipping_charge_class",
  "XTracker::Schema::Result::Public::ShippingChargeClass",
  { id => "class_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "shipping_charge_late_postcodes",
  "XTracker::Schema::Result::Public::ShippingChargeLatePostcode",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "shipping_description",
  "XTracker::Schema::Result::Shipping::Description",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "state_shipping_charges",
  "XTracker::Schema::Result::Public::StateShippingCharge",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ups_service_availabilities",
  "XTracker::Schema::Result::Public::UpsServiceAvailability",
  { "foreign.shipping_charge_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9qdCn0jkFchxsq+kazbczg

use XTracker::Constants::FromDB qw(
    :shipping_charge_class
);
use XTracker::Utilities qw/ duration_from_time_of_day /;

__PACKAGE__->inflate_column(
    latest_nominated_dispatch_daytime => {
        inflate => \&duration_from_time_of_day,
    },
);

=head1 METHODS

=head2 is_ground : $is_

Return boolean whether this Shipping Charge Class is Ground.

=cut

sub is_ground {
    my $self = shift;
    return $self->shipping_charge_class->id == $SHIPPING_CHARGE_CLASS__GROUND;
}

=head2 is_nominated_day : Bool

Return boolean whether this Shipping Charge is a Nominated Day charge
or not.

=cut

sub is_nominated_day {
    my $self = shift;
    return !! $self->latest_nominated_dispatch_daytime;
}

=head2 find_by_sku : ( $shipping_charge_row? )

Return the first row identified by $sku, or nothing if it doesn't
exist.

(SKU should be unique, but there is no constraint for that, so YMMV)

=cut

sub find_by_sku {
    my ($self, $sku) = @_;
    return $self->search({ sku => $sku })->first;
}

=head2 product_id

Return a C<product_id> split out from the SKU.

=cut

sub product_id {
    my $self = shift;
    my ($product_id, $size_id) = split /-/, $self->sku;
    return $product_id+0;
}

=head2 size_id

Return a C<size_id> split out from the SKU.

=cut

sub size_id {
    my $self = shift;
    my ($product_id, $size_id) = split /-/, $self->sku;
    return $size_id+0;
}

=head2 has_country_charges

Returns a boolean indicating whether there are C<country_charges> associated
with this C<ShippingCharge>.

=cut

sub has_country_charges {
    my $self = shift;

    return 1 if $self->count_related('country_charges') > 0;

    return;
}

=head2 has_region_charges

Returns a boolean indicating whether there are C<region_charges> associated
with this C<ShippingCharge>.

=cut

sub has_region_charges {
    my $self = shift;

    return 1 if $self->count_related('region_charges') > 0;

    return;
}

=head2 country_charges_payload

Returns an array_ref of hash_refs of country charge data.

  [{
    price => 1,
    currency => 'GBP',
    country => 'GB',
  }, ... ]

=cut

sub country_charges_payload {
    my $self = shift;

    my @charges;
    my $country_charges_rs = $self->country_charges;
    while ( my $charge = $country_charges_rs->next ) {
        push @charges, {
            price => $charge->charge,
            currency => $charge->currency->currency,
            country => $charge->country->code,
        };
    }

    return \@charges;
}

=head2 region_charges_payload

Returns an array_ref of hash_refs of region charge data.

  [{
    price => 1,
    currency => 'GBP',
    region => 'Europe',
  }, ... ]

=cut

sub region_charges_payload {
    my $self = shift;

    my @charges;
    my $region_charges_rs = $self->region_charges;
    while ( my $charge = $region_charges_rs->next ) {
        push @charges, {
            price => $charge->charge,
            currency => $charge->currency->currency,
            region => $charge->region->region,
        };
    }

    return \@charges;
}

1;
