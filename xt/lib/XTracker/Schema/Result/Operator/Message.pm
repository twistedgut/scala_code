use utf8;
package XTracker::Schema::Result::Operator::Message;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("operator.message");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "operator.message_id_seq",
  },
  "subject",
  { data_type => "text", default_value => "[No Subject]", is_nullable => 0 },
  "body",
  { data_type => "text", is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "recipient_id",
  { data_type => "integer", is_nullable => 0 },
  "sender_id",
  { data_type => "integer", is_nullable => 0 },
  "viewed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "deleted",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HHOTgU87TzeWKhGGQdwvWg

__PACKAGE__->belongs_to(
    'recipient' => 'XTracker::Schema::Result::Public::Operator',
    { 'foreign.id' => 'self.recipient_id' }
);

__PACKAGE__->belongs_to(
    'sender' => 'XTracker::Schema::Result::Public::Operator',
    { 'foreign.id' => 'self.sender_id' }
);

1;
