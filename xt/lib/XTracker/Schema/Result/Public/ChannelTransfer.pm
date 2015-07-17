use utf8;
package XTracker::Schema::Result::Public::ChannelTransfer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.channel_transfer");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "channel_transfer_id_seq",
  },
  "product_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "from_channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "to_channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "status_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "channel_transfer_picks",
  "XTracker::Schema::Result::Public::ChannelTransferPick",
  { "foreign.channel_transfer_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "channel_transfer_putaways",
  "XTracker::Schema::Result::Public::ChannelTransferPutaway",
  { "foreign.channel_transfer_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "from_channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "from_channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "log_channel_transfers",
  "XTracker::Schema::Result::Public::LogChannelTransfer",
  { "foreign.channel_transfer_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "product",
  "XTracker::Schema::Result::Public::Product",
  { id => "product_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "status",
  "XTracker::Schema::Result::Public::ChannelTransferStatus",
  { id => "status_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "to_channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "to_channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:SxKa/PLttmw8/Et1dT/w7Q

use DateTime;

sub set_status {
    my ($self,$new_status,$operator_id) = @_;

    $self->update({status_id => $new_status});
    $self->add_to_log_channel_transfers({
        status_id => $new_status,
        operator_id => $operator_id,
    });
}

1;
