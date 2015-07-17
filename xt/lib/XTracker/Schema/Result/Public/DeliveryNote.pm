use utf8;
package XTracker::Schema::Result::Public::DeliveryNote;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.delivery_note");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "delivery_note_id_seq",
  },
  "created_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "created",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "modified_by",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "modified",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "description",
  { data_type => "text", is_nullable => 0 },
  "delivery_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "creator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "created_by" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "delivery",
  "XTracker::Schema::Result::Public::Delivery",
  { id => "delivery_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "modifier",
  "XTracker::Schema::Result::Public::Operator",
  { id => "modified_by" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:dGLEHsCb6DXfZ8jsMhIOPA

sub edit_note {

    my ( $record, $operator_id, $desc )= @_;

    my $timestamp = 'current_timestamp(0)';

    $record->update(
        {
            modified_by => $operator_id,
            modified    => \$timestamp,
            description => $desc,
        }
    );

    return;
}

sub is_first {

    my $record = shift;

    my $first_note =
        $record->result_source->schema->resultset('Public::DeliveryNote')
        ->search(
            { 'delivery_id' => $record->delivery_id, },
            { 'order_by'    => 'created', },
        )->first;

    if ( $first_note->id == $record->id ) {
        return 1;
    }

    return;

}

1;
