use utf8;
package XTracker::Schema::Result::Public::ProductDepartment;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.product_department");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product_department_id_seq",
  },
  "department",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "product_attributes",
  "XTracker::Schema::Result::Public::ProductAttribute",
  { "foreign.product_department_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:GJxh1Ll0OWTmH2UTvffTsw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
