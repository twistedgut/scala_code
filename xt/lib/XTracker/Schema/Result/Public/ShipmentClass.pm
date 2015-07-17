use utf8;
package XTracker::Schema::Result::Public::ShipmentClass;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_class");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_class_id_seq",
  },
  "class",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "shipments",
  "XTracker::Schema::Result::Public::Shipment",
  { "foreign.shipment_class_id" => "self.id" },
  undef,
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:v5whVCeo+NtAow7N92It+g

use XTracker::Shipment::Classify;

# Documenting what the different classes mean, because I always forget.
# TODO would probably be more convenient to document this in the DB table itself
#
# Standard          - regular customer shipment
# Re-Shipment       - For when we (quite rarely) have to re-ship the exact same items.
# Exchange          - Customer is returning items
# Replacement       - Shipment never arrived to customer. This happens very rarely.
#                     This is one result of a 'Lost' shipment. Send a replacement shipment.
# Sample            - Not used
# Press             - Not used
# Transfer Shipment - Shipment full of stock to be used as samples to go to the sample room
# RTV Shipment      - Not used

# READ!
# These $shipment->shipment_class->is_sample/customer etc is the correct and object
# oriented way to ask if something is a sample etc.

# However since this is dbix, calling $obj->shipment_class-> involves a database call
# unless the data is prefetched, or it involves left join to fetch the data ahead of time.

# use the XTracker::Shipment::Classify package above to avoid making these db calls

=head2 is_sample

See XTracker::Shipment::Classify->is_sample

=cut

sub is_sample { XTracker::Shipment::Classify->new->is_sample(shift->id); }

=head2 is_customer

See XTracker::Shipment::Classify->is_customer

=cut

sub is_customer { XTracker::Shipment::Classify->new->is_customer(shift->id); }

=head2 is_rtv

See XTracker::Shipment::Classify->is_rtv

=cut

sub is_rtv { XTracker::Shipment::Classify->new->is_rtv(shift->id); }

=head2 type

See XTracker::Shipment::Classify->type

=cut

sub type { XTracker::Shipment::Classify->new->type(shift->id); }


=head2 get_sample_classes

See XTracker::Shipment::Classify->get_sample_classes

=cut

sub get_sample_classes { XTracker::Shipment::Classify->new->get_sample_classes; }

1;
