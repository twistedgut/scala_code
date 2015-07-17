use utf8;
package XTracker::Schema::Result::Public::Flag;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.flag");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "flag_id_seq",
  },
  "description",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "flag_type_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "customer_flags",
  "XTracker::Schema::Result::Public::CustomerFlag",
  { "foreign.flag_id" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "flag_type",
  "XTracker::Schema::Result::Public::FlagType",
  { id => "flag_type_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);
__PACKAGE__->has_many(
  "order_flags",
  "XTracker::Schema::Result::Public::OrderFlag",
  { "foreign.flag_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipment_flags",
  "XTracker::Schema::Result::Public::ShipmentFlag",
  { "foreign.flag_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Uz4qmA/Fme6/eWMKlm8kqg


=head2 icon_name

    $string = $self->icon_name;

The name of the Icon to display for the Flag, this is the description with
underscores replacing any spaces.

=cut

sub icon_name {
    my $self    = shift;

    my $icon_name   = $self->description;
    $icon_name      =~ s/\s/_/g;

    return $icon_name;
}


1;
