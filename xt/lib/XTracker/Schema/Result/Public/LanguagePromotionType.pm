use utf8;
package XTracker::Schema::Result::Public::LanguagePromotionType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.language__promotion_type");
__PACKAGE__->add_columns(
  "language_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "promotion_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("language_id", "promotion_type_id");
__PACKAGE__->belongs_to(
  "language",
  "XTracker::Schema::Result::Public::Language",
  { id => "language_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "promotion_type",
  "XTracker::Schema::Result::Public::PromotionType",
  { id => "promotion_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:9t3XQ8Tt9KgkP+FGs+UOhQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
