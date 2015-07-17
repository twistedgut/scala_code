use utf8;
package XTracker::Schema::Result::Public::SubType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.sub_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sub_type_id_seq",
  },
  "sub_type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "product_type_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("sub_type_key", ["sub_type"]);
__PACKAGE__->has_many(
  "products",
  "XTracker::Schema::Result::Public::Product",
  { "foreign.sub_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:h+xBl84WKkUvGUYTg1390g

# This column is unused, it's kept so as not to break any old code that
# might need it
__PACKAGE__->remove_column("product_type_id");

# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
