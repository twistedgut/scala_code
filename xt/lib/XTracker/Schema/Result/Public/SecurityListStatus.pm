use utf8;
package XTracker::Schema::Result::Public::SecurityListStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.security_list_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "security_list_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("security_list_status_status_key", ["status"]);
__PACKAGE__->has_many(
  "ip_address_lists",
  "XTracker::Schema::Result::Fraud::IpAddressList",
  { "foreign.status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1VOaQs+psB6kP/Efckz6qA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
