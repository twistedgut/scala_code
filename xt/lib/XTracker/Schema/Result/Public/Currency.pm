use utf8;
package XTracker::Schema::Result::Public::Currency;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.currency");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "currency_id_seq",
  },
  "currency",
  { data_type => "varchar", is_nullable => 1, size => 3 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("currency_currency_key", ["currency"]);
__PACKAGE__->has_many(
  "countries",
  "XTracker::Schema::Result::Public::Country",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "country_charges",
  "XTracker::Schema::Result::Shipping::CountryCharge",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "customer_credits",
  "XTracker::Schema::Result::Public::CustomerCredit",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "pre_orders",
  "XTracker::Schema::Result::Public::PreOrder",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "price_countries",
  "XTracker::Schema::Result::Public::PriceCountry",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "price_defaults",
  "XTracker::Schema::Result::Public::PriceDefault",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "price_purchases",
  "XTracker::Schema::Result::Public::PricePurchase",
  { "foreign.wholesale_currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "price_regions",
  "XTracker::Schema::Result::Public::PriceRegion",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_details",
  "XTracker::Schema::Result::Promotion::Detail",
  { "foreign.target_currency" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "purchase_orders",
  "XTracker::Schema::Result::Public::PurchaseOrder",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "region_charges",
  "XTracker::Schema::Result::Shipping::RegionCharge",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "renumerations",
  "XTracker::Schema::Result::Public::Renumeration",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "returns_charges",
  "XTracker::Schema::Result::Public::ReturnsCharge",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sales_conversion_rate_destination_currencies",
  "XTracker::Schema::Result::Public::SalesConversionRate",
  { "foreign.destination_currency" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "sales_conversion_rate_source_currencies",
  "XTracker::Schema::Result::Public::SalesConversionRate",
  { "foreign.source_currency" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_charges",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "super_purchase_orders",
  "XTracker::Schema::Result::Public::SuperPurchaseOrder",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "voucher_products",
  "XTracker::Schema::Result::Voucher::Product",
  { "foreign.currency_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "voucher_purchase_orders",
  "XTracker::Schema::Result::Voucher::PurchaseOrder",
  { "foreign.currency_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:tZaJ0Cxlyf7TRGqQyQ5PVQ

use Carp;

use XTracker::Database::Currency        qw( get_currency_glyph_map );


sub conversion_rate_to {
    my ( $self, $to ) = @_;

    my $dest_currency = $self->result_source
                             ->resultset
                             ->find($to, { key => 'currency_currency_key' } );

    croak "$to not found in currency table" unless $dest_currency;

    # sales conversion should take into account start & end dates of rates
    # as there might be multiple per currency but some might have ended
    my $sales_conversion_rate
        = $self->sales_conversion_rate_source_currencies->search({
            destination_currency => $dest_currency->id,
            date_start => { '<' => \"current_timestamp" },
        },
        {
            order_by => 'date_start DESC',
        })->first;
    carp $self->currency. " could not be converted to $to - no conversion rate"
        unless $sales_conversion_rate;

    return $sales_conversion_rate->conversion_rate;
}

=head2 get_glyph_html_entity

    $string = $currency->get_glyph_html_entity;

Will return the HTML entity for the Currency Glyph.

=cut

sub get_glyph_html_entity {
    my $self    = shift;

    my $dbh = $self->result_source->schema->storage->dbh;

    my $map = get_currency_glyph_map( $dbh );

    return $map->{ $self->id } // '';
}

1;
