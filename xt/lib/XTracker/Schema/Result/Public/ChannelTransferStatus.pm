use utf8;
package XTracker::Schema::Result::Public::ChannelTransferStatus;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.channel_transfer_status");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "channel_transfer_status_id_seq",
  },
  "status",
  { data_type => "varchar", is_nullable => 0, size => 100 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("channel_transfer_status_status_key", ["status"]);
__PACKAGE__->has_many(
  "channel_transfers",
  "XTracker::Schema::Result::Public::ChannelTransfer",
  { "foreign.status_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "log_channel_transfers",
  "XTracker::Schema::Result::Public::LogChannelTransfer",
  { "foreign.status_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:HtugdQXMkFy3ghjeUHzNgA


# You can replace this text with custom content, and it will be preserved on regeneration
1;
