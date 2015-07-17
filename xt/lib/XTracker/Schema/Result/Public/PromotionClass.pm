use utf8;
package XTracker::Schema::Result::Public::PromotionClass;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.promotion_class");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "promotion_class_id_seq",
  },
  "class",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "promotion_types",
  "XTracker::Schema::Result::Public::PromotionType",
  { "foreign.promotion_class_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Ma0jQ11AZukRpW9QAYkXUA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
