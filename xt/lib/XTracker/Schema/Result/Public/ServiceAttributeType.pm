use utf8;
package XTracker::Schema::Result::Public::ServiceAttributeType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.service_attribute_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "service_attribute_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 50 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("service_attribute_type_type_key", ["type"]);
__PACKAGE__->has_many(
  "customer_service_attribute_logs",
  "XTracker::Schema::Result::Public::CustomerServiceAttributeLog",
  { "foreign.service_attribute_type_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SikpCijHZVmvLvpeoCyC0g


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
