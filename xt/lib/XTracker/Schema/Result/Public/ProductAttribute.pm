use utf8;
package XTracker::Schema::Result::Public::ProductAttribute;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.product_attribute");
__PACKAGE__->add_columns(
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 1 },
  "description",
  { data_type => "text", is_nullable => 0 },
  "long_description",
  { data_type => "text", is_nullable => 1 },
  "short_description",
  { data_type => "text", is_nullable => 1 },
  "designer_colour",
  { data_type => "text", is_nullable => 1 },
  "editors_comments",
  { data_type => "text", is_nullable => 1 },
  "keywords",
  { data_type => "text", is_nullable => 1 },
  "recommended",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "designer_colour_code",
  { data_type => "varchar", is_nullable => 1, size => 100 },
  "size_scheme_id",
  {
    data_type      => "integer",
    default_value  => 1,
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  "custom_lists",
  { data_type => "text", is_nullable => 1 },
  "act_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "pre_order",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "operator_id",
  { data_type => "integer", is_nullable => 1 },
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "product_attribute_id_seq",
  },
  "sample_correct",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "sample_colour_correct",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "product_department_id",
  {
    data_type      => "integer",
    default_value  => 0,
    is_foreign_key => 1,
    is_nullable    => 0,
  },
  "fit_notes",
  { data_type => "text", is_nullable => 1 },
  "style_notes",
  { data_type => "text", is_nullable => 1 },
  "editorial_approved",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "use_measurements",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
  "editorial_notes",
  { data_type => "text", is_nullable => 1 },
  "outfit_links",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "use_fit_notes",
  { data_type => "boolean", default_value => \"false", is_nullable => 1 },
  "size_fit",
  { data_type => "text", is_nullable => 1 },
  "runway_look",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "related_facts",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("product_attribute_product_id_key", ["product_id"]);
__PACKAGE__->belongs_to(
  "act",
  "XTracker::Schema::Result::Public::SeasonAct",
  { id => "act_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "product_department",
  "XTracker::Schema::Result::Public::ProductDepartment",
  { id => "product_department_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "size_scheme",
  "XTracker::Schema::Result::Public::SizeScheme",
  { id => "size_scheme_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:vNhHELJtSgP7R8MZRNM75g

use XTracker::DBEncode qw(encode_db decode_db);

__PACKAGE__->load_components('FilterColumn');
foreach ( qw/ name description
              long_description
              short_description
              editors_comments
              designer_colour
            / ) {
    __PACKAGE__->filter_column( $_ => {
        filter_from_storage => sub { decode_db($_[1]) },
        filter_to_storage => sub { encode_db($_[1]) },
    } );
}

1;
