use utf8;
package XTracker::Schema::Result::Public::Language;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.language");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "language_id_seq",
  },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 5 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("language_code_key", ["code"]);
__PACKAGE__->has_many(
  "customer_attributes",
  "XTracker::Schema::Result::Public::CustomerAttribute",
  { "foreign.language_preference_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "language__promotion_types",
  "XTracker::Schema::Result::Public::LanguagePromotionType",
  { "foreign.language_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_marketing_promotion__languages",
  "XTracker::Schema::Result::Public::LinkMarketingPromotionLanguage",
  { "foreign.language_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "orders",
  "XTracker::Schema::Result::Public::Orders",
  { "foreign.customer_language_preference_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many(
  "promotion_types",
  "language__promotion_types",
  "promotion_type",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:foq+EZGraRTG4WSVTXs1lw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
