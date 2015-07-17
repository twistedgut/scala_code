use utf8;
package XTracker::Schema::Result::Public::ShippingChargeClass;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipping_charge_class");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipping_charge_class_id_seq",
  },
  "class",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "upgrade",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "shipping_charges",
  "XTracker::Schema::Result::Public::ShippingCharge",
  { "foreign.class_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "upgradable_from",
  "XTracker::Schema::Result::Public::ShippingChargeClass",
  { "foreign.upgrade" => "self.id" },
  undef,
);
__PACKAGE__->belongs_to(
  "upgradable_to",
  "XTracker::Schema::Result::Public::ShippingChargeClass",
  { id => "upgrade" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);
__PACKAGE__->has_many(
  "ups_services",
  "XTracker::Schema::Result::Public::UpsService",
  { "foreign.shipping_charge_class_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:bG4uUuFzUS1/tpiSJ20BVQ


=head2 get_upgrade

badly named columns (not ending in _id)
is why I provide a get_upgrade option to
return the shipment charge class object
we're upgrade to

=cut

sub get_upgrade {
    my $self = shift;
    return undef unless $self->upgrade;

    return $self->result_source
        ->schema
        ->resultset('Public::ShippingChargeClass')
        ->find($self->upgrade);
}

=head2 is_air

Air is something of a special case because some items
can't go by air.

=cut

sub is_air {
    my $self = shift;
    return ($self->class eq 'Air');
}

=head2 next_upgrade_is_first_to_air

If this shipment class can be upgraded, is it the first time we
upgrade the shipment to air?

=cut

sub next_upgrade_is_first_to_air {
    my $self = shift;
    my $upgrade_obj = $self->get_upgrade;

    return 0 if (!defined($upgrade_obj));
    return ( (!$self->is_air) && $upgrade_obj->is_air );
}

1; # be true
