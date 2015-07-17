use utf8;
package XTracker::Schema::Result::Public::Box;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.box");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "box_id_seq",
  },
  "box",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "weight",
  { data_type => "numeric", is_nullable => 1, size => [10, 2] },
  "volumetric_weight",
  { data_type => "numeric", is_nullable => 1, size => [10, 2] },
  "active",
  { data_type => "boolean", is_nullable => 1 },
  "length",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 2],
  },
  "width",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 2],
  },
  "height",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [10, 2],
  },
  "label_id",
  { data_type => "integer", is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "is_conveyable",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "requires_tote",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "sort_order",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("box_channel_id_sort_order_key", ["channel_id", "sort_order"]);
__PACKAGE__->has_many(
  "carrier_box_weights",
  "XTracker::Schema::Result::Public::CarrierBoxWeight",
  { "foreign.box_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "inner_boxes",
  "XTracker::Schema::Result::Public::InnerBox",
  { "foreign.outer_box_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_boxes",
  "XTracker::Schema::Result::Public::ShipmentBox",
  { "foreign.box_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipping_attributes",
  "XTracker::Schema::Result::Public::ShippingAttribute",
  { "foreign.box_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:hLvM0GkfB+ivxYEA6Bt+zQ

use XTracker::Config::Local qw/config_var/;

=head2 update_sort_order

Updates the sort order of boxes where the sort_order for the box submitted is
already in use by a different box.

NOTE: This method works with the assumption that we are only interested in the
sort order per channel so that boxes from different channels may have the same
sort_order. This is currently not an issue as boxes are only displayed
per channel.


=cut

sub update_sort_order {
    my ( $self, $sort_order ) = @_;

    my $box = $self->result_source->resultset->search({
        channel_id => $self->channel_id,
        sort_order => $sort_order })->first;

    if ( $box && $box->box ne $self->box ) {
        $box->update_sort_order( $sort_order+1 );
        $box->update( { sort_order => $sort_order+1 } );
    }
}

=head2 update_volumetric_weight

Updates the volumetric weight of the box

=cut

sub update_volumetric_weight {
    my ( $self ) = @_;
    my $length = $self->length // 0.0;
    my $width  = $self->width // 0.0;
    my $height = $self->height // 0.0;
    $self->update( { volumetric_weight => ($length * $width * $height) / 6000 } );
}

=head2 is_small

Returns whether the box is small or not

=cut

sub is_small {
    my ( $self ) = @_;
    return !$self->is_conveyable && $self->requires_tote;
}

=head2 is_large

Returns whether the box is large or not

=cut

sub is_large {
    my ( $self ) = @_;
    return !$self->is_conveyable && !$self->requires_tote;
}


=head2 cubic_volume

Returns the cubic volume of the box.

=cut

sub cubic_volume {
    my ( $self ) = @_;

    return (($self->length * $self->width * $self->height) / 1_000_000);
}

=head2 pims_code

The code for this box as identified in the Packaging Inventory Management System

=cut
sub pims_code {
  my ($self) = @_;

  #  <DC-code>-outer-<id>
  sprintf('%s-outer-%s',
    config_var('DistributionCentre', 'name'),
    $self->id
  );
}


1;
