use utf8;
package XTracker::Schema::Result::Public::ReturnArrival;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.return_arrival");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "return_arrival_id_seq",
  },
  "return_airway_bill",
  { data_type => "varchar", is_nullable => 0, size => 30 },
  "date",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
    original      => { default_value => \"now()" },
  },
  "dhl_tape_on_box",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "box_damaged",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "damage_description",
  { data_type => "text", is_nullable => 1 },
  "return_delivery_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "operator_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "removed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "packages",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "return_removal_reason_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "removal_notes",
  { data_type => "text", is_nullable => 1 },
  "goods_in_processed",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "last_updated",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 1,
    original      => { default_value => \"now()" },
  },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(
  "return_arrival_return_airway_bill_key",
  ["return_airway_bill"],
);
__PACKAGE__->has_many(
  "link_return_arrival__shipments",
  "XTracker::Schema::Result::Public::LinkReturnArrivalShipment",
  { "foreign.return_arrival_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "operator",
  "XTracker::Schema::Result::Public::Operator",
  { id => "operator_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "return_delivery",
  "XTracker::Schema::Result::Public::ReturnDelivery",
  { id => "return_delivery_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "return_removal_reason",
  "XTracker::Schema::Result::Public::ReturnRemovalReason",
  { id => "return_removal_reason_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->many_to_many("shipments", "link_return_arrival__shipments", "shipment");


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:sPQ0R0uVReCQZs9ugmPgsw

__PACKAGE__->has_many(
    return_items => 'XTracker::Schema::Result::Public::ReturnItem',
    { 'foreign.return_airway_bill' => 'self.return_airway_bill' },
    { cascade_delete => 0 },
);

__PACKAGE__->has_many(
    return_awb_shipments => 'XTracker::Schema::Result::Public::Shipment',
    { 'foreign.return_airway_bill' => 'self.return_airway_bill' },
    { cascade_delete => 0 },
);

=head2 complete($dhl_tape, $damaged, $damage_description) :

Update with the given parameters.

=cut

sub complete {
    my ( $record, $dhl_tape, $damaged, $damage_description ) = @_;

    my $arg_ref = {
        dhl_tape_on_box => 0,
        box_damaged     => 0,
    };

    if ( defined $dhl_tape ) {
        $arg_ref->{dhl_tape_on_box} = 1;
    }
    if ( defined $damaged ) {
        $arg_ref->{box_damaged} = 1;
    }
    if ( defined $damage_description ) {
        $arg_ref->{damage_description} = $damage_description;
    }

    $record->update( $arg_ref );
    return;
}

=head2 add_package() : $dbic_row

Increment the package count.

=cut

sub add_package {
    return $_[0]->update({ packages => \['packages + 1'] });
}

=head2 remove_package() : $dbic_row

Decrement the package count. Deletes the row if our package count less than
one.

=cut

sub remove_package {
    my $self = shift;
    return $self->delete if $self->packages <= 1;
    return $self->update({ packages => \['packages - 1']});
}

=head2 shipment() : $shipment_row|Undef

Return the associated shipment if there is one, joining on the return air
waybill. Note that if these get recycled the returned shipment will be
incorrect. Not something to worry about right now, but at some point we might
want to rethink this.

=cut

sub shipment { $_[0]->return_awb_shipments->next; }

1;
