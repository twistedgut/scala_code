use utf8;
package XTracker::Schema::Result::Public::PreOrderNote;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.pre_order_note");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "pre_order_note_id_seq",
  },
  "pre_order_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "note",
  { data_type => "text", is_nullable => 0 },
  "note_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "date",
  {
    data_type     => "timestamp",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "note_type",
  "XTracker::Schema::Result::Public::PreOrderNoteType",
  { id => "note_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "pre_order",
  "XTracker::Schema::Result::Public::PreOrder",
  { id => "pre_order_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:WIqZCEdS3srNlTUTzLHPmQ

use XTracker::Constants::FromDB qw( :pre_order_note_type );

use Moose;
with 'XTracker::Schema::Role::WithStatus' => {
         column => 'note_type_id',
         statuses => {
             shipment_address_change
                  => $PRE_ORDER_NOTE_TYPE__SHIPMENT_ADDRESS_CHANGE,

             online_fraud_finance
                  => $PRE_ORDER_NOTE_TYPE__ONLINE_FRAUD_FSLASH_FINANCE,

             pre_order_item
                  => $PRE_ORDER_NOTE_TYPE__PRE_DASH_ORDER_ITEM,

             misc => $PRE_ORDER_NOTE_TYPE__MISC
         }
     };

use XTracker::DBEncode qw( decode_db );

__PACKAGE__->load_components('FilterColumn');

__PACKAGE__->filter_column($_ => {
        filter_from_storage => sub { decode_db($_[1]) },
    }) for (qw( note ));

1;
