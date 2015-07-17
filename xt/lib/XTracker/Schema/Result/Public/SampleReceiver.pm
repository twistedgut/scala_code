use utf8;
package XTracker::Schema::Result::Public::SampleReceiver;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.sample_receiver");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "sample_receiver_id_seq",
  },
  "name",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "address_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "do_not_use",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "address",
  "XTracker::Schema::Result::Public::OrderAddress",
  { id => "address_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:oLLfJ4V7j6nRbZG/ukQgbA


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
