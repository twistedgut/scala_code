use utf8;
package XTracker::Schema::Result::Public::Season;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.season");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "season_id_seq",
  },
  "season",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "season_year",
  { data_type => "smallint", default_value => 9999, is_nullable => 1 },
  "season_code",
  {
    data_type      => "smallint",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  "active",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.season_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "promotion_detail_seasons",
  "XTracker::Schema::Result::Promotion::DetailSeasons",
  { "foreign.season_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "purchase_orders",
  "XTracker::Schema::Result::Public::PurchaseOrder",
  { "foreign.season_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "season_conversion_rates",
  "XTracker::Schema::Result::Public::SeasonConversionRate",
  { "foreign.season_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:TxWdvb9xMA78U9qz3RFFfw


sub compare {
    my ($self,$other) = @_;

    return $self->season_year <=> $other->season_year ||
        $self->season_code <=> $other->season_code;
}

1;
