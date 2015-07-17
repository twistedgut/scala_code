use utf8;
package XTracker::Schema::Result::WebContent::Template;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("web_content.template");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "web_content.template_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "designer_landing",
  { data_type => "boolean", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("template_name_key", ["name"]);
__PACKAGE__->has_many(
  "pages",
  "XTracker::Schema::Result::WebContent::Page",
  { "foreign.template_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:I+1norabCCqhFiKP8MljcA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
