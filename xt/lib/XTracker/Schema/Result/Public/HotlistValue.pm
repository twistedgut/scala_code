use utf8;
package XTracker::Schema::Result::Public::HotlistValue;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.hotlist_value");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "hotlist_value_id_seq",
  },
  "hotlist_field_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "value",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "order_nr",
  { data_type => "varchar", is_nullable => 1, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "hotlist_field",
  "XTracker::Schema::Result::Public::HotlistField",
  { id => "hotlist_field_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:93aZ2iJJ9JhuVkkXdRO1mg


=head2 format_for_sync

    $hash_ref   = $self->format_for_sync( 'add' | 'delete' etc.);

Returns a Hash Ref in the format required by the Sync AMQ Producer.

Pass in the Action to be performed on it such as 'add'.

=cut

sub format_for_sync {
    my ( $self, $action )   = @_;

    return {
        action                  => $action,
        hotlist_field_name      => $self->hotlist_field->field,
        channel_config_section  => $self->channel->business->config_section,
        value                   => $self->value,
        order_number            => $self->order_nr,
    };
}

1;
