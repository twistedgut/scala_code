use utf8;
package XTracker::Schema::Result::Public::Country;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.country");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "country_id_seq",
  },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 2 },
  "country",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "sub_region_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "proforma",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "returns_proforma",
  { data_type => "integer", default_value => 0, is_nullable => 1 },
  "currency_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "shipping_zone_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "dhl_tariff_zone",
  { data_type => "varchar", is_nullable => 0, size => 3 },
  "local_currency_code",
  { data_type => "varchar", is_nullable => 1, size => 5 },
  "phone_prefix",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "is_commercial_proforma",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("country_code_key", ["code"]);
__PACKAGE__->add_unique_constraint("country_country_key", ["country"]);
__PACKAGE__->has_many(
  "country_charges",
  "XTracker::Schema::Result::Shipping::CountryCharge",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_duty_rates",
  "XTracker::Schema::Result::Public::CountryDutyRate",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_promotion_type_welcome_packs",
  "XTracker::Schema::Result::Public::CountryPromotionTypeWelcomePack",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_shipment_types",
  "XTracker::Schema::Result::Public::CountryShipmentType",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_shipping_charges",
  "XTracker::Schema::Result::Public::CountryShippingCharge",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_subdivisions",
  "XTracker::Schema::Result::Public::CountrySubdivision",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_tax_codes",
  "XTracker::Schema::Result::Public::CountryTaxCode",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "country_tax_rate",
  "XTracker::Schema::Result::Public::CountryTaxRate",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "currency",
  "XTracker::Schema::Result::Public::Currency",
  { id => "currency_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "duty_rule_values",
  "XTracker::Schema::Result::Public::DutyRuleValue",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__countries",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionCountry",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "local_exchange_rates",
  "XTracker::Schema::Result::Public::LocalExchangeRate",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "postcode_shipping_charges",
  "XTracker::Schema::Result::Public::PostcodeShippingCharge",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "price_countries",
  "XTracker::Schema::Result::Public::PriceCountry",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "product_type_tax_rates",
  "XTracker::Schema::Result::Public::ProductTypeTaxRate",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "return_country_refund_charges",
  "XTracker::Schema::Result::Public::ReturnCountryRefundCharge",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "returns_charges",
  "XTracker::Schema::Result::Public::ReturnsCharge",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ship_restriction_allowed_countries",
  "XTracker::Schema::Result::Public::ShipRestrictionAllowedCountry",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "ship_restriction_exclude_postcodes",
  "XTracker::Schema::Result::Public::ShipRestrictionExcludePostcode",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_attributes",
  "XTracker::Schema::Result::Public::ShippingAttribute",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_charge_late_postcodes",
  "XTracker::Schema::Result::Public::ShippingChargeLatePostcode",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "state_shipping_charges",
  "XTracker::Schema::Result::Public::StateShippingCharge",
  { "foreign.country_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "sub_region",
  "XTracker::Schema::Result::Public::SubRegion",
  { id => "sub_region_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "tax_rule_values",
  "XTracker::Schema::Result::Public::TaxRuleValue",
  { "foreign.country_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:ZL5+79PiY8LEKm3CPYzJHg

=head1 NAME

XTracker::Schema::Result::Public::Country

=cut

use Carp;

use XTracker::Config::Local qw(
    address_formatting_messages_for_country
);

=head1 METHODS

=head2 welcome_pack

A shortcut for C<< $self->country_promotion_type_welcome_pack->promotion_type >>.

=cut

sub welcome_pack {
    warn __PACKAGE__ ." this method shouldn't be used. To find out if a "
        ."country has a welcome pack you need to combine it with a channel";
    my $row = $_[0]->country_promotion_type_welcome_packs;
    return unless $row;
    return $row->promotion_type;
}

=head2 can_refund_for_return

    $boolean    = $country->can_refund_for_return( $REFUND_CHARGE_TYPE__??? .. n );

You can pass in one or more Refund Charge Types (such as '_TAX' & '_DUTY') and this method will only return TRUE
if ALL of the types are TRUE. It will check the 'can_refund_for_return' flag on the 'return_country_refund_charge'
table to see if it is TRUE or FALSE.

If there are NO records for the Country for an individual Type then it will see if the Countries Sub-Region has that Type
but it won't do this if the Country does have a record and the flag is FALSE.

=cut

sub can_refund_for_return {
    my ($self, @types) = @_; # Refund Charge Types passed in to Check
                             # for ALL, must be TRUE

    if ( !@types ) {
        croak "No Refund Charge Types passed to 'country->can_refund_for_return'";
    }

    my $retval  = 1;

    # for each Refund Charge Type get
    # the record for the Country
    foreach my $type ( @types ) {
        # there should only be one record per type per country
        my $rec = $self->return_country_refund_charges
                            ->search( { refund_charge_type_id => $type } )->first;
        if ( defined $rec ) {
            $retval = $retval & $rec->can_refund_for_return;        # bitwise AND means only TRUE if ALL TRUE
        }
        else {  # no record found so check the Country's Sub-Region
            $retval = $retval & $self->sub_region->can_refund_for_return( $type );
        }
    }

    return $retval;
}

=head2 no_charge_for_exchange

    $boolean    = $country->no_charge_for_exchange( $REFUND_CHARGE_TYPE__??? .. n );

You can pass in one or more Refund Charge Types (such as '_TAX' & '_DUTY') and this method will only return TRUE
if ALL of the types are TRUE. It will check the 'no_charge_for_exchange' flag on the 'return_country_refund_charge'
table to see if it is TRUE or FALSE.

If there are NO records for the Country for an individual Type then it will see if the Countries Sub-Region has that Type
but it won't do this if the Country does have a record and the flag is FALSE.

=cut

sub no_charge_for_exchange {
    my ($self, @types) = @_; # Refund Charge Types passed in to Check
                             # for, ALL must be TRUE

    if ( !@types ) {
        croak "No Refund Charge Types passed to 'country->no_charge_for_exchange'";
    }

    my $retval  = 1;

    # for each Refund Charge Type get
    # the record for the Country
    foreach my $type ( @types ) {
        # there should only be one record per type per country
        my $rec = $self->return_country_refund_charges
                            ->search( { refund_charge_type_id => $type } )->first;
        if ( defined $rec ) {
            $retval = $retval & $rec->no_charge_for_exchange;       # bitwise AND means only TRUE if ALL TRUE
        }
        else {  # no record found so check the Country's Sub-Region
            $retval = $retval & $self->sub_region->no_charge_for_exchange( $type );
        }
    }

    return $retval;
}

=head2 address_formatting_messages

This is just a wrapper for the C<address_formatting_messages_for_country>
method in L<XTracker::Config::Local>, which contains more details.

    my $messages = $schema->resultset('Public::Country')->find( $id );

=cut

sub address_formatting_messages {
    my $self = shift;

    return address_formatting_messages_for_country(
        $self->result_source->schema, $self->code );

}

1;
