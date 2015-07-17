use utf8;
package XTracker::Schema::Result::Public::InnerBox;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.inner_box");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "inner_box_id_seq",
  },
  "inner_box",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "sort_order",
  { data_type => "integer", is_nullable => 0 },
  "active",
  { data_type => "boolean", default_value => \"true", is_nullable => 1 },
  "outer_box_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "channel_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "grouping_id",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
  "channel",
  "XTracker::Schema::Result::Public::Channel",
  { id => "channel_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->belongs_to(
  "outer_box",
  "XTracker::Schema::Result::Public::Box",
  { id => "outer_box_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "shipment_boxes",
  "XTracker::Schema::Result::Public::ShipmentBox",
  { "foreign.inner_box_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:P+roT2x5uPRhklGZGfx7OQ

use XTracker::Config::Local qw/config_var/;

=head2 update_sort_order

Updates the sort order of inner boxes where the sort_order for the inner box
submitted is already in use by a different inner box.

NOTE: This method works with the assumption that we are only interested in the
sort order per channel so that boxes from different channels may have the same
sort_order. This is currently not an issue as boxes are only displayed
per channel.

=cut

sub update_sort_order {
    my ( $self, $sort_order ) = @_;

    my $inner_box = $self->result_source->resultset->search({
        channel_id => $self->channel_id,
        sort_order => $sort_order })->first;

    if ( $inner_box && $inner_box->inner_box ne $self->inner_box ) {
        $inner_box->update_sort_order( $sort_order+1 );
        $inner_box->update( { sort_order => $sort_order+1 } );
    }
}

=head2 pims_code

The code for this box as identified in the Packaging Inventory Management System

=cut
sub pims_code {
  my ($self) = @_;

  #  <DC-code>-inner-<id>
  sprintf('%s-inner-%s',
    config_var('DistributionCentre', 'name'),
    $self->id
  );
}

1;
