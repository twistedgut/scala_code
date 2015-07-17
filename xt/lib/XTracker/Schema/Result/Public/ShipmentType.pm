use utf8;
package XTracker::Schema::Result::Public::ShipmentType;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';
__PACKAGE__->load_components("InflateColumn::DateTime");
__PACKAGE__->table("public.shipment_type");
__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "shipment_type_id_seq",
  },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->has_many(
  "country_shipment_types",
  "XTracker::Schema::Result::Public::CountryShipmentType",
  { "foreign.shipment_type_id" => "self.id" },
  undef,
);
__PACKAGE__->might_have(
  "dispatch_lane_offset",
  "XTracker::Schema::Result::Public::DispatchLaneOffset",
  { "foreign.shipment_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "link_shipment_type__dispatch_lanes",
  "XTracker::Schema::Result::Public::LinkShipmentTypeDispatchLane",
  { "foreign.shipment_type_id" => "self.id" },
  undef,
);
__PACKAGE__->has_many(
  "shipments",
  "XTracker::Schema::Result::Public::Shipment",
  { "foreign.shipment_type_id" => "self.id" },
  undef,
);
__PACKAGE__->many_to_many(
  "dispatch_lanes",
  "link_shipment_type__dispatch_lanes",
  "dispatch_lane",
);


# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7ce03oMiD/6HKzgp/N0RSQ

sub get_lane{
    my $self = shift;

    my $total_nr_of_lanes = $self->dispatch_lanes->count;

    my $shipment_type;
    if ($total_nr_of_lanes) {
        # this shipment type has configured lanes, so use it
        $shipment_type = $self;
    } else {
        # no configured dispatch lanes, so use 'Unknown' dispatch lane config
        $shipment_type = $self
            ->result_source
            ->schema
            ->resultset('Public::ShipmentType')
            ->search({ type => 'Unknown' }, { rows => 1 })
            ->slice(0,0)
            ->single;
        $total_nr_of_lanes = $shipment_type->dispatch_lanes->count;
        if (!$shipment_type) {
            die 'This DC has no configured dispatch lanes and there is no dispatch lane configuration for shipment type "Unknown" to use instead.';
        }
    }

    # Offset is the index in the array of dispatch lanes for this shipment_type
    my $dispatch_lane_offset = $shipment_type->dispatch_lane_offset;
    my $prev_offset = $dispatch_lane_offset ? $dispatch_lane_offset->lane_offset : 0;
    my $next_offset = ($prev_offset + 1) % $total_nr_of_lanes;

    $shipment_type->dispatch_lane_offset->update({lane_offset => $next_offset});

    my $lane = $shipment_type
        ->dispatch_lanes
        ->search(
            undef,
            {
                rows => 1,
                offset => $next_offset,
            }
        )
        ->slice(0,0)
        ->single
        ->lane_nr;
    return $lane;
}

1;
